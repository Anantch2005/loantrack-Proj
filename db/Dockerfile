
FROM postgres:16-alpine

COPY migrations/001_create_loans.sql /docker-entrypoint-initdb.d/01-schema.sql
COPY seeds/002_seed_loans.sql /docker-entrypoint-initdb.d/02-seed.sql
