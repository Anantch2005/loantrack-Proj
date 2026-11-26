
import logging
import threading
import time

import psycopg
from psycopg_pool import ConnectionPool

from app.config import DATABASE_URL

logger = logging.getLogger("loantrack.database")

pool = None
pool_lock = threading.Lock()
stop_event = threading.Event()
ready_event = threading.Event()


def database_retry_worker():
    global pool

    delay = 2

    while not stop_event.is_set():
        try:
            logger.info("Checking PostgreSQL connection...")

            with psycopg.connect(DATABASE_URL) as conn:
                conn.execute("SELECT 1")

            new_pool = ConnectionPool(
                conninfo=DATABASE_URL,
                min_size=1,
                max_size=10,
                open=True,
                timeout=5,
            )

            with new_pool.connection() as conn:
                conn.execute("SELECT 1")

            with pool_lock:
                pool = new_pool
                ready_event.set()

            logger.info("PostgreSQL connection pool initialized.")
            return

        except Exception as exc:
            logger.warning(
                "Database unavailable: %s. Retrying in %s seconds.",
                exc,
                delay,
            )
            stop_event.wait(delay)
            delay = min(delay * 2, 30)


def start_database_worker():
    thread = threading.Thread(
        target=database_retry_worker,
        daemon=True,
        name="database-retry-worker",
    )
    thread.start()


def get_pool():
    with pool_lock:
        return pool


def is_database_ready():
    current_pool = get_pool()

    if current_pool is None:
        return False

    try:
        with current_pool.connection(timeout=2) as conn:
            conn.execute("SELECT 1")
        return True
    except Exception:
        return False


def close_database():
    stop_event.set()
    current_pool = get_pool()

    if current_pool is not None:
        current_pool.close()
