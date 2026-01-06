"""Clara voice agent entry point."""

import signal
import sys
import threading
from typing import Any

import uvicorn
from dotenv import load_dotenv
from livekit.agents import AgentServer, JobContext

from clara.agent import create_session
from clara.health import app as health_app
from clara.logging import get_logger, setup_logging

load_dotenv()

logger = get_logger(__name__)

server = AgentServer()


def handle_shutdown(signum: int, _frame: Any) -> None:
    """Handle graceful shutdown."""
    sig_name = signal.Signals(signum).name
    logger.info("shutdown_signal_received", signal=sig_name)
    sys.exit(0)


@server.rtc_session(agent_name="clara-agent")
async def entrypoint(ctx: JobContext) -> None:
    """Handle incoming RTC sessions."""
    await create_session(ctx)


def _run_health_server() -> None:
    """Run health server in a separate thread."""
    uvicorn.run(health_app, host="0.0.0.0", port=8080, log_level="warning")


def main() -> None:
    """Run the Clara agent."""
    setup_logging()

    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)

    # Start health server in background thread
    health_thread = threading.Thread(target=_run_health_server, daemon=True)
    health_thread.start()
    logger.info("health_server_started", port=8080)

    logger.info("agent_starting")

    from livekit import agents

    agents.cli.run_app(server)


if __name__ == "__main__":
    main()
