#!/usr/bin/env python3
"""Generate IBDers gut app icons, adaptive layers, and splash logos."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
MASTER = 1024

TEAL = (13, 148, 136)  # 0xFF0D9488
TEAL_DEEP = (15, 118, 110)  # 0xFF0F766E
TEAL_SOFT = (20, 184, 166)  # 0xFF14B8A6
GUT = (240, 253, 250)  # 0xFFF0FDFA
GUT_SOFT = (204, 251, 241)  # 0xFFCCFBF1
ACCENT = (245, 158, 11)  # 0xFFF59E0B


def catmull(points: list[tuple[float, float]], samples: int = 36) -> list[tuple[float, float]]:
    if len(points) < 2:
        return list(points)
    pts = [points[0], *points, points[-1]]
    out: list[tuple[float, float]] = []
    for i in range(len(pts) - 3):
        p0, p1, p2, p3 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            x = 0.5 * (
                2 * p1[0]
                + (-p0[0] + p2[0]) * t
                + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3
            )
            y = 0.5 * (
                2 * p1[1]
                + (-p0[1] + p2[1]) * t
                + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3
            )
            out.append((x, y))
    out.append(points[-1])
    return out


def stroke(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], width: float, color) -> None:
    r = width / 2.0
    w = max(1, int(round(width)))
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        draw.line([(x0, y0), (x1, y1)], fill=color, width=w)
        draw.ellipse([x0 - r, y0 - r, x0 + r, y0 + r], fill=color)
        draw.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=color)
    if pts:
        x, y = pts[-1]
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def shape_mask(size: int, shape: str) -> Image.Image:
    s = 4
    W = size * s
    mask = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(mask)
    if shape == "round":
        d.ellipse([0, 0, W - 1, W - 1], fill=255)
    else:
        radius = int(W * 0.22)
        d.rounded_rectangle([0, 0, W - 1, W - 1], radius=radius, fill=255)
    return mask.resize((size, size), Image.Resampling.LANCZOS)


_GRADIENT = None


def gradient_bg() -> Image.Image:
    global _GRADIENT
    if _GRADIENT is not None:
        return _GRADIENT
    W = MASTER
    img = Image.new("RGB", (W, W), TEAL)
    px = img.load()
    cx, cy = W * 0.38, W * 0.34
    max_d = math.hypot(W, W) * 0.72
    for y in range(W):
        for x in range(W):
            t = min(1.0, math.hypot(x - cx, y - cy) / max_d)
            t = t * t * (3 - 2 * t)
            r = int(TEAL_SOFT[0] * (1 - t) + TEAL_DEEP[0] * t)
            g = int(TEAL_SOFT[1] * (1 - t) + TEAL_DEEP[1] * t)
            b = int(TEAL_SOFT[2] * (1 - t) + TEAL_DEEP[2] * t)
            mid = 0.35
            if 0.35 < t < 0.7:
                k = 1.0 - abs(t - 0.525) / 0.175
                r = int(r * (1 - mid * k) + TEAL[0] * (mid * k))
                g = int(g * (1 - mid * k) + TEAL[1] * (mid * k))
                b = int(b * (1 - mid * k) + TEAL[2] * (mid * k))
            px[x, y] = (r, g, b)
    _GRADIENT = img.filter(ImageFilter.SMOOTH)
    return _GRADIENT


def make_base(size: int, shape: str = "square") -> Image.Image:
    img = gradient_bg().resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    mask = shape_mask(size, shape)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, mask=mask)
    out.putalpha(mask)
    return out


def draw_gut_layer(gut_color=GUT, soft_color=GUT_SOFT, accent_color=ACCENT) -> Image.Image:
    """Stylized large + small intestine mark in MASTER space (1024)."""
    S = 4
    layer = Image.new("RGBA", (MASTER * S, MASTER * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def sc(x: float, y: float) -> tuple[float, float]:
        return (x * S, y * S)

    def pts(ctrl):
        return catmull([sc(x, y) for x, y in ctrl])

    colon_ctrl = [
        (305, 710),
        (285, 620),
        (272, 500),
        (278, 390),
        (310, 305),
        (375, 255),
        (470, 232),
        (580, 232),
        (680, 255),
        (748, 305),
        (778, 380),
        (785, 480),
        (776, 585),
        (745, 675),
        (695, 745),
        (630, 800),
        (580, 850),
        (555, 900),
    ]
    small_ctrl = [
        (360, 420),
        (430, 395),
        (530, 392),
        (620, 415),
        (665, 460),
        (620, 515),
        (530, 540),
        (430, 538),
        (370, 515),
        (345, 560),
        (385, 620),
        (465, 650),
        (555, 648),
        (635, 622),
        (675, 672),
        (635, 730),
        (555, 758),
        (480, 755),
        (430, 730),
    ]

    colon_path = pts(colon_ctrl)
    small_path = pts(small_ctrl)

    colon_w = 62 * S
    small_w = 40 * S

    stroke(d, small_path, width=small_w, color=soft_color + (255,))
    stroke(d, colon_path, width=colon_w, color=gut_color + (255,))

    if accent_color is not None:
        ax, ay = sc(530, 230)
        ar = 15 * S
        d.ellipse([ax - ar, ay - ar, ax + ar, ay + ar], fill=accent_color + (255,))

    return layer.resize((MASTER, MASTER), Image.Resampling.LANCZOS)


_GUT_LAYER = None
_GUT_MONO = None


def gut_layer() -> Image.Image:
    global _GUT_LAYER
    if _GUT_LAYER is None:
        _GUT_LAYER = draw_gut_layer()
    return _GUT_LAYER


def gut_monochrome() -> Image.Image:
    global _GUT_MONO
    if _GUT_MONO is None:
        _GUT_MONO = draw_gut_layer(gut_color=(255, 255, 255), soft_color=(255, 255, 255), accent_color=None)
    return _GUT_MONO


def compose_icon(size: int, shape: str = "square") -> Image.Image:
    base = make_base(size, shape=shape)
    gut = gut_layer().resize((size, size), Image.Resampling.LANCZOS)
    base.alpha_composite(gut)
    mask = shape_mask(size, shape)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(base, mask=mask)
    out.putalpha(mask)
    return out


def compose_foreground(size: int) -> Image.Image:
    """Adaptive icon foreground: gut in the safe center of a transparent canvas."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # keep mark inside ~66% safe zone
    mark = int(size * 0.62)
    gut = gut_layer().resize((mark, mark), Image.Resampling.LANCZOS)
    off = (size - mark) // 2
    canvas.alpha_composite(gut, (off, off))
    return canvas


def compose_monochrome(size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark = int(size * 0.62)
    gut = gut_monochrome().resize((mark, mark), Image.Resampling.LANCZOS)
    off = (size - mark) // 2
    canvas.alpha_composite(gut, (off, off))
    return canvas


def _load_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        r"C:\Windows\Fonts\segoeuib.ttf",
        r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\arialbd.ttf",
        r"C:\Windows\Fonts\arial.ttf",
        r"/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def compose_splash_logo(size: int) -> Image.Image:
    """Centered gut mark + IBDers wordmark for splash screens (transparent bg)."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark = int(size * 0.72)
    gut = gut_layer().resize((mark, mark), Image.Resampling.LANCZOS)
    ox = (size - mark) // 2
    oy = int(size * 0.08)
    canvas.alpha_composite(gut, (ox, oy))

    font = _load_font(int(size * 0.12))
    text = "IBDers"
    d = ImageDraw.Draw(canvas)
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (size - tw) // 2 - bbox[0]
    ty = int(size * 0.82)
    d.text((tx, ty), text, font=font, fill=GUT + (255,))
    return canvas


def to_opaque_rgb(img: Image.Image, bg=TEAL) -> Image.Image:
    flat = Image.new("RGB", img.size, bg)
    if img.mode == "RGBA":
        flat.paste(img, mask=img.getchannel("A"))
    else:
        flat = img.convert("RGB")
    return flat


def save_all() -> None:
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"

    # classic square + round launchers
    android_map = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for dens, px in android_map.items():
        folder = android_res / f"mipmap-{dens}"
        folder.mkdir(parents=True, exist_ok=True)
        icon = compose_icon(px, shape="square")
        to_opaque_rgb(icon).save(folder / "ic_launcher.png", optimize=True)
        rnd = compose_icon(px, shape="round")
        rnd.save(folder / "ic_launcher_round.png", optimize=True)

    # adaptive icon layers (108dp canvas)
    adaptive_map = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }
    for dens, px in adaptive_map.items():
        folder = android_res / f"mipmap-{dens}"
        folder.mkdir(parents=True, exist_ok=True)
        compose_foreground(px).save(folder / "ic_launcher_foreground.png", optimize=True)
        compose_monochrome(px).save(folder / "ic_launcher_monochrome.png", optimize=True)

    # splash logo (nodpi, large enough for all screens)
    nodpi = android_res / "drawable-nodpi"
    nodpi.mkdir(parents=True, exist_ok=True)
    compose_splash_logo(512).save(nodpi / "launch_logo.png", optimize=True)

    # iOS AppIcon
    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_specs = [
        (20, 1),
        (20, 2),
        (20, 3),
        (29, 1),
        (29, 2),
        (29, 3),
        (40, 1),
        (40, 2),
        (40, 3),
        (60, 2),
        (60, 3),
        (76, 1),
        (76, 2),
        (83.5, 2),
        (1024, 1),
    ]
    for base, scale in ios_specs:
        px = int(round(base * scale))
        name = f"Icon-App-{base:g}x{base:g}@{scale}x.png"
        img = compose_icon(px, shape="square")
        to_opaque_rgb(img).save(ios_dir / name, optimize=True)

    # iOS LaunchImage
    launch_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    for name, px in (("LaunchImage.png", 200), ("LaunchImage@2x.png", 400), ("LaunchImage@3x.png", 600)):
        compose_splash_logo(px).save(launch_dir / name, optimize=True)

    brand_dir = (ROOT.parents[1] / "docs" / "assets").resolve()
    brand_dir.mkdir(parents=True, exist_ok=True)
    preview = compose_icon(512, shape="square")
    to_opaque_rgb(preview).save(brand_dir / "ibders-app-icon.png", optimize=True)
    round_preview = compose_icon(512, shape="round")
    round_preview.save(brand_dir / "ibders-app-icon-round.png", optimize=True)
    compose_splash_logo(512).save(brand_dir / "ibders-splash-logo.png", optimize=True)

    print("icons + adaptive + splash written")


if __name__ == "__main__":
    save_all()
