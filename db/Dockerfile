FROM alpine:3.20 AS builder

WORKDIR /build

COPY migrations/ ./migrations/
COPY seeds/ ./seeds/


FROM postgres:16-alpine AS runtime

COPY --from=builder \
    /build/migrations/001_create_loans.sql \
    /docker-entrypoint-initdb.d/01-schema.sql

COPY --from=builder \
    /build/seeds/002_seed_loans.sql \
    /docker-entrypoint-initdb.d/02-seed.sql