"""Standalone BullMQ consumer (no HTTP). Useful for queue-only deployments."""

from __future__ import annotations

import asyncio
import logging

from .main import run_bullmq_worker

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("parse-worker. standalone")


async def _main() -> None:
    logger.info("starting standalone worker")
    await run_bullmq_worker()


if __name__ == "__main__":
    try:
        asyncio.run(_main())
    except KeyboardInterrupt:
        logger.info("stopped")
