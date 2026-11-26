
import os

DB_HOST = os.getenv("DB_HOST", "db")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "loantrack")
DB_USER = os.getenv("DB_USER", "loantrack_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

DATABASE_URL = (
    f"host={DB_HOST} port={DB_PORT} dbname={DB_NAME} "
    f"user={DB_USER} password={DB_PASSWORD} connect_timeout=3"
)
