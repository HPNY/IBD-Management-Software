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
    engine_detail: str | None = None


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
    skill: dict[str, Any] | None = None,
) -> ParseResult:
    images: list[bytes] = []
    if text is None and raw_pdf is not None:
        text, images = extract_text_or_images(raw_pdf)

    # 1) 任务下发的库内 Skill 优先  2) 本地样例 Skill  3) AI
    effective_skill = skill
    if effective_skill is None and hospital and report_type:
        effective_skill = load_skill(hospital, report_type)

    if effective_skill is not None:
        parsed = skill_parse(effective_skill, text or "")
        if parsed.items:
            return ParseResult(
                engine="skill",
                date=parsed.date,
                items=[i.model_dump() for i in parsed.items],
                skill_version=effective_skill.get("version"),
            )

    parsed = ai_parse(text=text or "", images=images)
    return ParseResult(
        engine="ai" if parsed.items else "ai-empty",
        date=parsed.date,
        items=[i.model_dump() for i in parsed.items],
        engine_detail=parsed.engine_detail,
    )


def fetch_object_bytes(data: dict[str, Any]) -> bytes | None:
    """按 storage.driver 取直传对象。"""
    object_key = data.get("objectKey") or ""
    if not object_key:
        return None

    storage = data.get("storage") or {}
    driver = storage.get("driver") or os.getenv("STORAGE_DRIVER", "local")

    if object_key.startswith("http://") or object_key.startswith("https://"):
        import urllib.request

        with urllib.request.urlopen(object_key, timeout=60) as resp:  # noqa: S310
            return resp.read()

    if driver == "s3":
        try:
            import boto3  # noqa: PLC0415
        except ImportError as exc:
            raise RuntimeError("boto3 required for S3 storage") from exc
        bucket = storage.get("bucket") or os.getenv("S3_BUCKET")
        endpoint = storage.get("endpoint") or os.getenv("S3_ENDPOINT")
        client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=os.getenv("S3_ACCESS_KEY_ID"),
            aws_secret_access_key=os.getenv("S3_SECRET_ACCESS_KEY"),
            region_name=os.getenv("S3_REGION", "us-east-1"),
        )
        obj = client.get_object(Bucket=bucket, Key=object_key)
        return obj["Body"].read()

    # local：objectKey 相对 STORAGE_LOCAL_DIR，也允许绝对路径
    local_dir = storage.get("localDir") or os.getenv("STORAGE_LOCAL_DIR", "var/uploads")
    candidates = []
    if os.path.isabs(object_key):
        candidates.append(object_key)
    candidates.append(os.path.join(local_dir, object_key))
    candidates.append(object_key)  # 兼容 worker 与 API 同机绝对相对路径
    for path in candidates:
        if os.path.isfile(path):
            with open(path, "rb") as f:
                return f.read()
    raise FileNotFoundError(f"object not found: {object_key}")


async def process_bullmq_job(job, *args: Any) -> dict[str, Any]:
    # bullmq-py 会传入 (job, token) 等额外位置参数
    data = job.data or {}
    text = data.get("text")
    raw: bytes | None = None

    if not text:
        raw = fetch_object_bytes(data)
        if raw is not None and not raw.lstrip()[:5].startswith(b"%PDF"):
            # 非 PDF（如 txt/ocr 文本）按文本处理
            try:
                text = raw.decode("utf-8")
                raw = None
            except UnicodeDecodeError:
                pass

    result = run_pipeline(
        raw_pdf=raw,
        text=text,
        hospital=data.get("hospitalHint") or "",
        report_type=data.get("reportType") or "",
        skill=data.get("skill"),
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
def health() -> dict[str, Any]:
    from .ai_engine import llm_port_config

    llm = llm_port_config()
    return {
        "status": "ok",
        "service": "ibd-parse-worker",
        "queue": QUEUE_NAME,
        "redis_configured": str(bool(os.getenv("REDIS_URL"))).lower(),
        "llm_configured": str(bool(llm["base"] and llm["key_set"])).lower(),
        "llm_model": llm["model"],
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
