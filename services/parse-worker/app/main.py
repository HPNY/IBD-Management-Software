"""Parse worker entry: health API + BullMQ consumer."""

from __future__ import annotations

import asyncio
import logging
import os
from contextlib import asynccontextmanager
from typing import Any
from urllib.parse import urlparse

from fastapi import FastAPI, File, UploadFile
from pydantic import BaseModel

from .ai_engine import ai_parse
from .pdf import extract_text_or_images
from .skill_engine import load_skill, skill_parse

logger = logging.getLogger("parse-worker")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

QUEUE_NAME = os.getenv("PARSE_QUEUE", "parse")


class ParseResult(BaseModel):
    engine: str
    date: str | None = None
    items: list[dict[str, Any]] = []
    skill_version: str | None = None


def redis_connection_options() -> dict[str, Any]:
    redis_url = os.getenv("REDIS_URL", "redis://127.0.0.1:6379")
    parsed = urlparse(redis_url)
    opts: dict[str, Any] = {
        "host": parsed.hostname or "127.0.0.1",
        "port": parsed.port or 6379,
    }
    if parsed.password:
        opts["password"] = parsed.password
    return opts


def run_pipeline(
    *,
    raw_pdf: bytes | None,
    text: str | None,
    hospital: str,
    report_type: str,
) -> ParseResult:
    images: list[bytes] = []
    if text is None and raw_pdf is not None:
        text, images = extract_text_or_images(raw_pdf)

    skill = load_skill(hospital, report_type) if hospital and report_type else None
    if skill is not None:
        parsed = skill_parse(skill, text or "")
        if parsed.items:
            return ParseResult(
                engine="skill",
                date=parsed.date,
                items=[i.model_dump() for i in parsed.items],
                skill_version=skill.get("version"),
            )

    parsed = ai_parse(text=text or "", images=images)
    return ParseResult(
        engine="ai",
        date=parsed.date,
        items=[i.model_dump() for i in parsed.items],
    )


async def process_bullmq_job(job, *args: Any) -> dict[str, Any]:
    # bullmq-py 会传入 (job, token) 等额外位置参数
    data = job.data or {}
    object_key = data.get("objectKey") or ""
    text = data.get("text")
    raw: bytes | None = None

    if not text and object_key and os.path.isfile(object_key):
        with open(object_key, "rb") as f:
            raw = f.read()

    result = run_pipeline(
        raw_pdf=raw,
        text=text,
        hospital=data.get("hospitalHint") or "",
        report_type=data.get("reportType") or "",
    )
    payload = result.model_dump()
    logger.info(
        "job %s engine=%s items=%d",
        data.get("jobId") or job.id,
        payload["engine"],
        len(payload.get("items") or []),
    )
    return payload


async def run_bullmq_worker() -> None:
    from bullmq import Worker

    connection = redis_connection_options()
    worker = Worker(
        QUEUE_NAME,
        process_bullmq_job,
        {
            "connection": connection,
            "concurrency": int(os.getenv("PARSE_CONCURRENCY", "2")),
        },
    )
    logger.info(
        "BullMQ worker listening queue=%s redis=%s:%s",
        QUEUE_NAME,
        connection["host"],
        connection["port"],
    )
    stop = asyncio.Event()
    try:
        await stop.wait()
    finally:
        await worker.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    task: asyncio.Task | None = None
    if os.getenv("REDIS_URL"):
        task = asyncio.create_task(run_bullmq_worker())
        logger.info("BullMQ background task started")
    else:
        logger.warning("REDIS_URL not set; queue consumer disabled")
    yield
    if task:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass


app = FastAPI(title="ibd-parse-worker", version="0.1.0", lifespan=lifespan)


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "ibd-parse-worker",
        "queue": QUEUE_NAME,
        "redis_configured": str(bool(os.getenv("REDIS_URL"))).lower(),
    }


@app.post("/parse", response_model=ParseResult)
async def parse_pdf(
    file: UploadFile = File(...),
    hospital: str = "",
    report_type: str = "",
) -> ParseResult:
    raw = await file.read()
    return run_pipeline(
        raw_pdf=raw,
        text=None,
        hospital=hospital,
        report_type=report_type,
    )


def main() -> None:
    import uvicorn

    port = int(os.getenv("PORT", "8081"))
    uvicorn.run(app, host="0.0.0.0", port=port)


if __name__ == "__main__":
    main()
