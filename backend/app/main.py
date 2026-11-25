
import logging
import os
from contextlib import asynccontextmanager
from decimal import Decimal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from psycopg.rows import dict_row

from app.database import (
    close_database,
    get_pool,
    is_database_ready,
    start_database_worker,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

logger = logging.getLogger("loantrack.api")


@asynccontextmanager
async def lifespan(app: FastAPI):
    start_database_worker()
    yield
    close_database()


app = FastAPI(title="LoanTrack API", version="1.0.0", lifespan=lifespan)


class LoanCreate(BaseModel):
    borrower_name: str = Field(min_length=1, max_length=150)
    loan_amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    property_city: str | None = Field(default=None, max_length=100)
    status: str = "PENDING"


def get_connection_pool():
    current_pool = get_pool()
    if current_pool is None:
        raise HTTPException(status_code=503, detail="Database not ready")
    return current_pool


@app.get("/healthz")
def health():
    return {"status": "alive"}


@app.get("/readyz")
def readiness():
    if not is_database_ready():
        raise HTTPException(status_code=503, detail="Database unavailable")
    return {"status": "ready", "database": "connected"}


@app.get("/loans")
def list_loans():
    current_pool = get_connection_pool()

    try:
        with current_pool.connection() as conn:
            conn.row_factory = dict_row
            loans = conn.execute(
                """
                SELECT id, borrower_name, loan_amount, property_city,
                       status, created_at
                FROM loans
                ORDER BY id
                """
            ).fetchall()

        return {
            "loans": loans,
            "served_by": os.getenv("HOSTNAME", "local"),
        }

    except Exception as exc:
        logger.exception("Failed to fetch loans")
        raise HTTPException(status_code=503, detail="Database query failed") from exc


@app.post("/loans", status_code=201)
def create_loan(loan: LoanCreate):
    current_pool = get_connection_pool()

    if loan.status not in {"PENDING", "APPROVED", "REJECTED", "DISBURSED"}:
        raise HTTPException(status_code=422, detail="Invalid loan status")

    try:
        with current_pool.connection() as conn:
            conn.row_factory = dict_row
            created = conn.execute(
                """
                INSERT INTO loans
                    (borrower_name, loan_amount, property_city, status)
                VALUES (%s, %s, %s, %s)
                RETURNING id, borrower_name, loan_amount, property_city,
                          status, created_at
                """,
                (
                    loan.borrower_name,
                    loan.loan_amount,
                    loan.property_city,
                    loan.status,
                ),
            ).fetchone()

        return {
            "loan": created,
            "served_by": os.getenv("HOSTNAME", "local"),
        }

    except Exception as exc:
        logger.exception("Failed to create loan")
        raise HTTPException(status_code=503, detail="Database insert failed") from exc
