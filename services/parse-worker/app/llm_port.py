"""OpenAI 兼容 Chat Completions 客户端（text / vision）。"""

from __future__ import annotations

import base64
import json
import os
import urllib.error
import urllib.request
from typing import Any


def llm_config() -> dict[str, Any]:
    return {
        "base": (os.getenv("LLM_API_BASE") or "").rstrip("/"),
        "key": os.getenv("LLM_API_KEY") or "",
        "model": os.getenv("LLM_MODEL") or "gpt-4o-mini",
        "timeout_sec": float(os.getenv("LLM_TIMEOUT_SEC") or "60"),
    }


def complete_json(
    *,
    system: str,
    user_text: str,
    images: list[bytes] | None = None,
    schema_hint: str,
) -> dict[str, Any]:
    """
    调用 OpenAI 兼容 /chat/completions，要求返回 JSON。
    无配置时抛 RuntimeError（调用方决定降级）。
    """
    cfg = llm_config()
    if not cfg["base"]:
        raise RuntimeError("LLM_API_BASE not set")
    if not cfg["key"]:
        raise RuntimeError("LLM_API_KEY not set")

    content: list[dict[str, Any]] = [{"type": "text", "text": user_text}]
    for raw in images or []:
        b64 = base64.b64encode(raw).decode("ascii")
        content.append(
            {
                "type": "image_url",
                "image_url": {"url": f"data:image/png;base64,{b64}"},
            }
        )

    payload = {
        "model": cfg["model"],
        "temperature": 0,
        "response_format": {"type": "json_object"},
        "messages": [
            {
                "role": "system",
                "content": system
                + f"\n只输出 JSON，结构：{schema_hint}",
            },
            {"role": "user", "content": content},
        ],
    }

    url = f"{cfg['base']}/chat/completions"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "content-type": "application/json",
            "authorization": f"Bearer {cfg['key']}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=cfg["timeout_sec"]) as resp:  # noqa: S310
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")[:500]
        raise RuntimeError(f"LLM HTTP {e.code}: {detail}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"LLM network error: {e}") from e

    try:
        message = body["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as e:
        raise RuntimeError(f"LLM unexpected response shape: {body!r:.200}") from e

    if isinstance(message, list):
        # 某些网关返回分段 content
        message = "".join(
            part.get("text", "") if isinstance(part, dict) else str(part)
            for part in message
        )
    message = (message or "").strip()
    # 去掉可能的 ```json 围栏
    if message.startswith("```"):
        message = message.split("```", 2)[1] if message.count("```") >= 2 else message
        if message.lower().startswith("json"):
            message = message[4:].lstrip()
    try:
        return json.loads(message)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"LLM returned non-JSON: {message[:200]!r}") from e
