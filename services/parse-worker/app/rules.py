"""Special rules + abnormal flags."""

from __future__ import annotations

import re
from typing import Any


def flag_value(value: float, ref_min: float | None, ref_max: float | None) -> str | None:
    if ref_min is not None and value < ref_min:
        return "low"
    if ref_max is not None and value > ref_max:
        return "high"
    return None


def apply_special_rules(
    items: list[Any],
    rules: list[dict[str, Any]],
    text: str,
) -> list[Any]:
    for rule in rules:
        if rule.get("filter") == "patient_id_mismatch":
            items = [i for i in items if not _looks_like_case_number(i.value)]
        elif rule.get("filter") == "crp_multiline":
            items = _fix_multiline_value(items, rule, text)
    return items


def _looks_like_case_number(value: float) -> bool:
    # 病案号误匹配：整数且位数过长
    return value.is_integer() and abs(int(value)) > 10_000_000


def _fix_multiline_value(items: list[Any], rule: dict[str, Any], text: str) -> list[Any]:
    label = rule.get("pattern")
    if not label:
        return items
    for item in items:
        if item.name == label or label in item.name:
            m = re.search(rule.get("next_line_pattern") or r"^([\d.]+)", text, re.M)
            if m:
                try:
                    item.value = float(m.group(1))
                except ValueError:
                    pass
    return items
