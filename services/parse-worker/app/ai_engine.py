"""AI fallback engine. Skeleton: local heuristics; plug LLMPort later."""

from __future__ import annotations

import os
from typing import Any

from pydantic import BaseModel

from .skill_engine import ParsedItem


class AiParseResult(BaseModel):
    date: str | None = None
    items: list[ParsedItem] = []


def ai_parse(*, text: str, images: list[bytes]) -> AiParseResult:
    """
    生产路径：text/images → OpenAI 兼容 complete_json(schema) → 规则校验。
    骨架：若无 LLM_API_BASE，返回空结果由客户端走手动录入。
    """
    _ = images
    if not os.getenv("LLM_API_BASE"):
        return AiParseResult()

    # TODO: 调用 LLM/VLM，按 PRD Prompt 输出 items JSON
    return AiParseResult()


def llm_port_config() -> dict[str, Any]:
    return {
        "base": os.getenv("LLM_API_BASE", ""),
        "key_set": bool(os.getenv("LLM_API_KEY")),
    }
