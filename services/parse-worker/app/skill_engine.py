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


def load_skill(hospital: str, report_type: str) -> dict[str, Any] | None:
    path = SKILL_DIR / f"{hospital}__{report_type}.json"
    if not path.exists():
        # 兜底：目录内任一匹配 hospital 字段的 skill
        for p in SKILL_DIR.glob("*.json"):
            data = json.loads(p.read_text(encoding="utf-8"))
            if data.get("hospital") == hospital and data.get("report_type") == report_type:
                return data
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def skill_parse(skill: dict[str, Any], text: str) -> SkillParseResult:
    if not text:
        return SkillParseResult()

    date = None
    date_rules = skill.get("date_extraction") or {}
    for key in ("primary", "fallback"):
        pattern = date_rules.get(key)
        if not pattern:
            continue
        m = re.search(pattern, text)
        if m:
            date = m.group(0)
            break

    items: list[ParsedItem] = []
    for rule in skill.get("items") or []:
        m = re.search(rule["pattern"], text)
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
