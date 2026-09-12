"""Parse worker entry: health API + queue consumer stub."""

from __future__ import annotations

import os
import threading
import time
from typing import Any

from fastapi import FastAPI, File, UploadFile
from pydantic import BaseModel

from .ai_engine import ai_parse
from .pdf import extract_text_or_images
from .skill_engine import load_skill, skill_parse

app = FastAPI(title="ibd-parse-worker", version="0.1.0")


class ParseResult(BaseModel):
    engine: str
    date: str | None = None
    items: list[dict[str, Any]] = []
    skill_version: str | None = None


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "ibd-parse-worker"}


@app.post("/parse", response_model=ParseResult)
async def parse_pdf(
    file: UploadFile = File(...),
    hospital: str = "",
    report_type: str = "",
) -> ParseResult:
    raw = await file.read()
    text, images = extract_text_or_images(raw)

    skill = load_skill(hospital, report_type) if hospital and report_type else None
    if skill is not None:
        parsed = skill_parse(skill, text)
        if parsed.items:
            return ParseResult(
                engine="skill",
                date=parsed.date,
                items=[i.model_dump() for i in parsed.items],
                skill_version=skill.get("version"),
            )

    parsed = ai_parse(text=text, images=images)
    return ParseResult(
        engine="ai",
        date=parsed.date,
        items=[i.model_dump() for i in parsed.items],
    )


def _queue_loop() -> None:
    """BullMQ/RQ 消费占位：有 Redis 时轮询；无 Redis 则空转。"""
    redis_url = os.getenv("REDIS_URL", "")
    if not redis_url:
        while True:
            time.sleep(30)
        return
    try:
        import redis  # noqa: PLC0415
    except ImportError:
        while True:
            time.sleep(30)
        return

    client = redis.Redis.from_url(redis_url)
    while True:
        try:
            item = client.blpop(["parse:jobs"], timeout=5)
            if item:
                # TODO: 反序列化任务 → 调 parse 管线 → 回写结果队列
                client.rpush("parse:results", item[1])
        except Exception:
            time.sleep(2)


def main() -> None:
    import uvicorn  # noqa: PLC0415

    threading.Thread(target=_queue_loop, daemon=True).start()
    port = int(os.getenv("PORT", "8081"))
    uvicorn.run(app, host="0.0.0.0", port=port)


if __name__ == "__main__":
    main()
