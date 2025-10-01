# syntax=docker/dockerfile:1

FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt ./
RUN pip install --user --no-cache-dir -r requirements.txt

FROM gcr.io/distroless/python3-debian12
ENV PYTHONPATH=/app
WORKDIR /app
COPY --from=build /root/.local /root/.local
COPY src ./src
ENTRYPOINT ["python3", "-m", "src"]
