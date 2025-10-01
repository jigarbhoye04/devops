from __future__ import annotations

from fastapi import FastAPI

app = FastAPI(title="Helios Analytics Service")


@app.get("/healthz", tags=["health"])
async def health_check() -> dict[str, str]:
    return {"status": "ok"}
