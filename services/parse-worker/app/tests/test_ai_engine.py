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
    print("ALL_PASS")
