"""Health check HTTP server."""

import asyncio
import time
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from uvicorn import Config, Server

from clara.logging import get_logger

logger = get_logger(__name__)

_start_time: float = 0


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncGenerator[None]:
    """Track server start time."""
    global _start_time
    _start_time = time.time()
    yield


app = FastAPI(lifespan=lifespan)


@app.get("/health")
async def health() -> dict:
    """Health check endpoint."""
    uptime = int(time.time() - _start_time) if _start_time else 0
    return {
        "status": "healthy",
        "uptime_seconds": uptime,
    }


async def run_health_server(host: str = "0.0.0.0", port: int = 8080) -> None:
    """Run the health check server."""
    config = Config(app=app, host=host, port=port, log_level="warning")
    server = Server(config)
    logger.info("health_server_start", host=host, port=port)
    await server.serve()


def start_health_server_background(host: str = "0.0.0.0", port: int = 8080) -> asyncio.Task:
    """Start health server as background task."""
    return asyncio.create_task(run_health_server(host, port))
