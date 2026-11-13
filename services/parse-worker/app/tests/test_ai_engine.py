"""AI 引擎单元冒烟（不依赖真实 LLM）。

运行: python -m app.tests.test_ai_engine
"""

from __future__ import annotations

import json
from unittest.mock import patch

from app.ai_engine import ai_parse
from app.llm_port import complete_json


def test_ai_parse_success() -> None:
    fake = {
        "date": "2026/03/01",
        "items": [
            {
                "name": "超敏C反应蛋白",
                "name_raw": "hs-CRP",
                "value": "8.2",
                "unit": "mg/L",
                "ref_min": 0,
                "ref_max": 5,
            },
            {"name": "白蛋白", "value": 42, "unit": "g/L", "ref_min": 40, "ref_max": 55},
        ],
    }

    with patch("app.ai_engine.complete_json", return_value=fake):
        result = ai_parse(text="hs-CRP 8.2 albumin 42", images=[])

    assert result.date == "2026-03-01", result.date
    assert len(result.items) == 2
    assert result.items[0].flag == "high"
    assert result.items[1].flag is None
    print("test_ai_parse_success OK", json.dumps(result.model_dump(), ensure_ascii=False))


def test_ai_parse_qualitative_keeps_text_not_nan() -> None:
    """C4：定性值不得变成 NaN，也不得让整份 JSON 序列化失败。"""
    fake = {
        "date": "2026-03-02",
        "items": [
            {"name": "隐血", "name_raw": "OB", "value": "阴性", "unit": None},
            {"name": "超敏C反应蛋白", "value": "8.2", "ref_min": 0, "ref_max": 5},
            {"name": "粪便钙卫蛋白", "value": ">1800", "unit": "ug/g"},
        ],
    }
    with patch("app.ai_engine.complete_json", return_value=fake):
        result = ai_parse(text="OB 阴性 hs-CRP 8.2 calprotectin >1800", images=[])

    assert len(result.items) == 3, result.items
    qualitative = result.items[0]
    assert qualitative.value is None
    assert qualitative.value_text == "阴性"
    assert qualitative.flag is None
    assert result.items[1].value == 8.2
    # 运算符值只保留原文，不做数值比较（V13-10）
    assert result.items[2].value is None
    assert result.items[2].value_text == ">1800"
    # 必须能序列化成合法 JSON（NaN 会产出非法 JSON）
    encoded = json.dumps(result.model_dump(), ensure_ascii=False, allow_nan=False)
    assert "NaN" not in encoded
    print("test_ai_parse_qualitative_keeps_text_not_nan OK", encoded)


def test_ai_parse_no_llm_degrades() -> None:
    with patch.dict("os.environ", {"LLM_API_BASE": "", "LLM_API_KEY": ""}):
        result = ai_parse(text="whatever", images=[])
    assert result.items == []
    assert result.engine_detail.startswith("error:") or result.engine_detail == "empty-input"
    print("test_ai_parse_no_llm_degrades OK", result.engine_detail)


def test_complete_json_requires_config() -> None:
    try:
        complete_json(system="s", user_text="u", schema_hint="{}")
        raise AssertionError("should raise without config")
    except RuntimeError as e:
        assert "LLM_API_BASE" in str(e)
        print("test_complete_json_requires_config OK")


if __name__ == "__main__":
    test_complete_json_requires_config()
    test_ai_parse_no_llm_degrades()
    test_ai_parse_success()
    test_ai_parse_qualitative_keeps_text_not_nan()
    print("ALL_PASS")
