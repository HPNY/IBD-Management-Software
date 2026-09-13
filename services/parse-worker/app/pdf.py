"""PDF text/image extraction via PyMuPDF."""

from __future__ import annotations

import io


def extract_text_or_images(raw: bytes) -> tuple[str, list[bytes]]:
    """Return (text, page_images). Text PDFs get text; scanned pages get images."""
    try:
        import fitz  # pymupdf
    except ImportError:
        # 骨架环境可能未装 pymupdf；返回空以便接口可测
        return "", []

    doc = fitz.open(stream=raw, filetype="pdf")
    texts: list[str] = []
    images: list[bytes] = []

    for page in doc:
        page_text = page.get_text("text") or ""
        texts.append(page_text)
        # 低文本页视为扫描件，3x 栅格化
        if len(page_text.strip()) < 40:
            pix = page.get_pixmap(matrix=fitz.Matrix(3, 3))
            images.append(pix.tobytes("png"))

    doc.close()
    return "\n".join(texts).strip(), images
