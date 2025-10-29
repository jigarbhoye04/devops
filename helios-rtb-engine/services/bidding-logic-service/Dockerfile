# syntax=docker/dockerfile:1

FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
COPY src ./src

FROM python:3.12-slim AS runtime
ENV PYTHONPATH=/app/src
WORKDIR /app
COPY --from=builder /install /usr/local
COPY --from=builder /app/src ./src
RUN useradd --create-home appuser
USER appuser
ENTRYPOINT ["python3", "-m", "src"]
