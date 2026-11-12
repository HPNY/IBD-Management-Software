"""AI 解析引擎：Skill 未命中时的 LLM/VLM 兜底。"""

from __future__ import annotations

import logging
import math
import re
from typing import Any

from pydantic import BaseModel, Field, ValidationError, field_validator

from .llm_port import complete_json
from .rules import flag_value
from .skill_engine import ParsedItem

logger = logging.getLogger("parse-worker.ai")

SYSTEM_PROMPT = (
    "你是一名医学检验报告解析助手。请从检验报告文本或图像中提取所有检验项目，"
    "返回 JSON。注意：项目名与数值可能跨行；过滤病案号/样本号等非检验数值；"
    "区分上限值（如\">1800\"）与具体数值；单位尽量保留原文。"
)

SCHEMA_HINT = (
    '{"date":"YYYY-MM-DD或null","items":[{"name":"中文项目名","name_raw":"原文/缩写",'
    '"value":数字,"unit":"单位|null","ref_min":数字|null,"ref_max":数字|null}]}'
)


class AiItemIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    name_raw: str | None = None
    # C4：允许定性结果（value=None, value_text 保留原文）
    value: float | None = None
    value_text: str | None = None
    unit: str | None = None
    ref_min: float | None = None
    ref_max: float | None = None

    @field_validator("name")
    @classmethod
    def _trim_name(cls, v: str) -> str:
        return v.strip()


class AiEnvelope(BaseModel):
    date: str | None = None
    items: list[AiItemIn] = Field(default_factory=list)


class AiParseResult(BaseModel):
    date: str | None = None
    items: list[ParsedItem] = []
    engine_detail: str = "llm"


def _normalize_date(raw: str | None) -> str | None:
    if not raw:
        return None
    s = str(raw).strip()
    if not s or s.lower() in {"null", "none", "unknown"}:
        return None
    # 2026/1/5 → 2026-01-05
    m = re.match(r"(\d{4})[/-](\d{1,2})[/-](\d{1,2})", s)
    if m:
        return f"{m.group(1)}-{int(m.group(2)):02d}-{int(m.group(3)):02d}"
    if re.match(r"^\d{4}-\d{2}-\d{2}$", s):
        return s
    return s[:10] if len(s) >= 10 else s


def _coerce_value(raw: Any) -> tuple[float | None, str | None] | None:
    """把 LLM 返回的 value 归一化为 (数值, 定性原文)。

    - 数值/可解析字符串 → (float, None)
    - 定性文本（阴性/未见异常等）→ (None, 原文)
    - 运算符值（>1800 / <0.5）→ (None, 原文)，不做数值比较（V13-10）
    - 空值 → None（调用方丢弃该条）
    """
    if raw is None or isinstance(raw, bool):
        return None
    if isinstance(raw, (int, float)):
        value = float(raw)
        if not math.isfinite(value):
            return None
        return value, None
    if not isinstance(raw, str):
        return None

    s = raw.strip()
    if not s:
        return None
    # 运算符值只保留原文：无法确认边界，不能当精确值参与 flag 判定
    if s[0] in "<>≥≤":
        return None, s
    numeric = re.sub(r"[^0-9.\-]", "", s)
    if not any(ch.isdigit() for ch in numeric):
        return None, s
    try:
        value = float(numeric)
    except ValueError:
        return None, s
    if not math.isfinite(value):
        return None, s
    return value, None


def _coerce_payload(data: dict[str, Any]) -> AiEnvelope:
    items_in: list[dict[str, Any]] = []
    raw_items = data.get("items") or data.get("results") or []
    if isinstance(raw_items, list):
        for it in raw_items:
            if not isinstance(it, dict):
                continue
            coerced = _coerce_value(it.get("value", it.get("result")))
            if coerced is None:
                continue
            value, value_text = coerced
            items_in.append(
                {
                    "name": it.get("name") or it.get("name_norm") or it.get("nameNorm") or "",
                    "name_raw": it.get("name_raw") or it.get("nameRaw") or it.get("alias"),
                    "value": value,
                    "value_text": value_text,
                    "unit": it.get("unit"),
                    "ref_min": it.get("ref_min", it.get("refMin", it.get("min"))),
                    "ref_max": it.get("ref_max", it.get("refMax", it.get("max"))),
                }
            )
    return AiEnvelope.model_validate({"date": data.get("date"), "items": items_in})


def ai_parse(*, text: str, images: list[bytes]) -> AiParseResult:
    """
    1) 调 OpenAI 兼容接口
    2) Pydantic 校验 + 规则补 flag
    3) 配置缺失/失败时返回空 items（客户端走手动录入）
    """
    if not text and not images:
        return AiParseResult(items=[], engine_detail="empty-input")

    user_text = text or "（无文本，请从图像识别检验项目）"
    try:
        raw = complete_json(
            system=SYSTEM_PROMPT,
            user_text=user_text,
            images=images[:4],  # 控制成本
            schema_hint=SCHEMA_HINT,
        )
        envelope = _coerce_payload(raw if isinstance(raw, dict) else {})
    except (RuntimeError, ValidationError) as e:
        logger.warning("ai_parse failed: %s", e)
        return AiParseResult(items=[], engine_detail=f"error:{type(e).__name__}")

    items: list[ParsedItem] = []
    for it in envelope.items:
        if not it.name:
            continue
        items.append(
            ParsedItem(
                name=it.name,
                name_raw=it.name_raw or it.name,
                value=it.value,
                value_text=it.value_text,
                unit=it.unit,
                ref_min=it.ref_min,
                ref_max=it.ref_max,
                flag=flag_value(it.value, it.ref_min, it.ref_max),
            )
        )

    logger.info("ai_parse date=%s items=%d", envelope.date, len(items))
    return AiParseResult(date=_normalize_date(envelope.date), items=items)


def llm_port_config() -> dict[str, Any]:
    from .llm_port import llm_config

    cfg = llm_config()
    return {
        "base": cfg["base"],
        "key_set": bool(cfg["key"]),
        "model": cfg["model"],
    }
