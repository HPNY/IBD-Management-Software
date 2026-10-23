"""Skill template engine (fast path)."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from pydantic import BaseModel

from .rules import apply_special_rules, flag_value

SKILL_DIR = Path(__file__).resolve().parent.parent / "skills"


class ParsedItem(BaseModel):
    name: str
    name_raw: str
    value: float
    unit: str | None = None
    ref_min: float | None = None
    ref_max: float | None = None
    flag: str | None = None


class SkillParseResult(BaseModel):
    date: str | None = None
    items: list[ParsedItem] = []


def _normalize_date(raw: str | None) -> str | None:
    """尽量输出 YYYY-MM-DD，避免 API date 列写入失败。"""
    if not raw:
        return None
    s = str(raw).strip()
    m = re.search(r"(\d{4})[/-](\d{1,2})[/-](\d{1,2})", s)
    if m:
        return f"{m.group(1)}-{int(m.group(2)):02d}-{int(m.group(3)):02d}"
    if re.match(r"^\d{4}-\d{2}-\d{2}$", s):
        return s
    return None


def load_skill(hospital: str, report_type: str) -> dict[str, Any] | None:
    # H7 加固：hospital/report_type 只允许安全字符，拒绝路径穿越与分隔符。
    import re as _re
    _safe = _re.compile(r"^[A-Za-z0-9\u4e00-\u9fff_-]{1,64}$")
    if not _safe.match(hospital or "") or not _safe.match(report_type or ""):
        return None
    _target = (SKILL_DIR / f"{hospital}__{report_type}.json").resolve()
    if _target.parent != SKILL_DIR.resolve():
        return None
    path = SKILL_DIR / f"{hospital}__{report_type}.json"
    if not path.exists():
        # 兜底：目录内任一匹配 hospital 字段的 skill
        for p in SKILL_DIR.glob("*.json"):
            data = json.loads(p.read_text(encoding="utf-8"))
            if data.get("hospital") == hospital and data.get("report_type") == report_type:
                return data
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def _is_unsafe_pattern(p: str) -> bool:
    """M5 ReDoS 防护：拒绝长度过长或含灾难性回溯结构的正则。"""
    if not isinstance(p, str) or len(p) > 200:
        return True
    # 拒绝嵌套量词（如 (a+)+、(a*)*、(a+)*）等经典灾难性回溯结构
    if re.search(r"\([^)]*[+*][^)]*\)\s*[+*{]", p):
        return True
    # 拒绝过多量词（>10 个 * / + / {n,}），降低回溯爆炸风险
    if len(re.findall(r"[+*]|\{\d+,?\d*\}", p)) > 10:
        return True
    return False


def safe_re_search(pattern: str, text: str):
    """M5：安全 re.search，拒绝危险正则后才执行，避免灾难性回溯 DoS。"""
    if _is_unsafe_pattern(pattern):
        return None
    try:
        return re.search(pattern, text)
    except re.error:
        return None


def skill_parse(skill: dict[str, Any], text: str) -> SkillParseResult:
    if not text:
        return SkillParseResult()

    date = None
    date_rules = skill.get("date_extraction") or {}
    for key in ("primary", "fallback"):
        pattern = date_rules.get(key)
        if not pattern:
            continue
        m = safe_re_search(pattern, text)
        if m:
            date = _normalize_date(m.group(0))
            if not date and m.groups():
                date = _normalize_date("-".join(g for g in m.groups() if g))
            break

    items: list[ParsedItem] = []
    for rule in skill.get("items") or []:
        m = safe_re_search(rule["pattern"], text)
        if not m:
            continue
        raw = m.group(1) if m.groups() else m.group(0)
        try:
            value = float(raw)
        except ValueError:
            continue
        ref = rule.get("ref_range") or [None, None]
        item = ParsedItem(
            name=rule["name"],
            name_raw=rule.get("alias") or rule["name"],
            value=value,
            unit=rule.get("unit"),
            ref_min=ref[0],
            ref_max=ref[1],
            flag=flag_value(value, ref[0], ref[1]),
        )
        items.append(item)

    items = apply_special_rules(items, skill.get("special_rules") or [], text)
    return SkillParseResult(date=date, items=items)