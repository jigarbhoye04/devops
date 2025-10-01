from __future__ import annotations

from fastapi import FastAPI
from fastapi.responses import JSONResponse
import uvicorn

app = FastAPI(title="Helios Bidding Logic Service")


@app.get("/healthz", tags=["health"])
async def health_check() -> JSONResponse:
    return JSONResponse({"status": "ok"})


def main() -> None:
    uvicorn.run(app, host="0.0.0.0", port=9000)


if __name__ == "__main__":
    main()
