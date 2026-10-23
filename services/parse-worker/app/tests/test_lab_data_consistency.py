"""检验套餐数据跨副本一致性守卫（纯文本比对，无第三方依赖）。

三处数据是「有意的跨语言副本」，非可运行时合并：
- packages/domain-types/src/index.ts   → CORE_LAB_NAMES（TS 常量，web/miniapp 用）
- apps/mobile/lib/core/lab/lab_panels.dart → kCoreLabNames/kLabPanels（Dart 编译期 const）
- app.js                              → CORE_LAB_NAMES + DEFAULT_PANELS（模板维护工具）

本守卫只锁定「核心名」与「套餐-小项」两处最易漂移的数据，任一处改动未同步即失败。
运行：python -m app.tests.test_lab_data_consistency（与 test_ai_engine 同法，CI 直接跑）。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]

# IBD 核心指标（PRD 2.1.3）——三处必须完全一致、顺序一致。
EXPECTED_CORE = [
    "超敏C反应蛋白",
    "血沉",
    "粪便钙卫蛋白",
    "淋巴细胞",
    "白蛋白",
    "血红蛋白",
    "尿酸",
]


def _names_in_bracket(text: str, marker: str) -> list[str]:
    """取 marker 之后 [ ... ] 内的中文字符串字面量（跳过注释）。"""
    i = text.find(marker)
    if i < 0:
        raise AssertionError(f"未找到标记：{marker}")
    j = text.index("[", i)
    depth = 0
    end = None
    for k in range(j, len(text)):
        if text[k] == "[":
            depth += 1
        elif text[k] == "]":
            depth -= 1
            if depth == 0:
                end = k
                break
    if end is None:
        raise AssertionError(f"括号未闭合：{marker}")
    body = text[j:end]
    return re.findall(r'"([^"\n]+)"|\'([^\'\n]+)\'', body) and [
        a or b for a, b in re.findall(r'"([^"\n]+)"|\'([^\'\n]+)\'', body)
    ]


def _panel_item_names(dart: str) -> set[str]:
    return set(re.findall(r"nameNorm:\s*'([^']+)'", dart)) | set(
        re.findall(r'nameNorm:\s*"([^"]+)"', dart)
    )


def _panel_item_names_js(js: str) -> set[str]:
    return set(re.findall(r'nameNorm:\s*"([^"]+)"', js))


def main() -> int:
    domain = (REPO / "packages/domain-types/src/index.ts").read_text(encoding="utf-8")
    dart = (REPO / "apps/mobile/lib/core/lab/lab_panels.dart").read_text(encoding="utf-8")
    appjs = (REPO / "app.js").read_text(encoding="utf-8")

    domain_core = _names_in_bracket(domain, "export const CORE_LAB_NAMES")
    dart_core = _names_in_bracket(dart, "const List<String> kCoreLabNames")
    js_core = _names_in_bracket(appjs, "const CORE_LAB_NAMES")

    assert domain_core == EXPECTED_CORE, f"domain-types 核心名漂移：{domain_core}"
    assert dart_core == EXPECTED_CORE, f"lab_panels.dart 核心名漂移：{dart_core}"
    assert js_core == EXPECTED_CORE, f"app.js 核心名漂移：{js_core}"

    # 套餐小项全集必须在 Dart 与 JS 两处保持一致（顺序/归属可不同，全集不可丢项）。
    dart_items = _panel_item_names(dart)
    js_items = _panel_item_names_js(appjs)
    assert dart_items == js_items, (
        f"套餐小项漂移：\n  仅 Dart={sorted(dart_items - js_items)}\n"
        f"  仅 JS={sorted(js_items - dart_items)}"
    )

    # 核心名必须是套餐小项的子集（否则趋势/发作预警取不到数据）。
    missing = [n for n in EXPECTED_CORE if n not in dart_items]
    assert not missing, f"核心名未出现在套餐小项中：{missing}"

    print("LAB_DATA_CONSISTENCY_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
