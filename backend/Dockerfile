
FROM python:3.12-slim-bookworm AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

RUN groupadd --system app && \
    useradd --system --gid app --home-dir /app app

WORKDIR /app

COPY --from=builder /install /usr/local
COPY --chown=app:app app/ ./app/

USER app

EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2)" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
