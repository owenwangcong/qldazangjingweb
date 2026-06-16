# -*- coding: utf-8 -*-
"""App icon generator for 乾隆大藏经 (ink-wash design language).

Design: 「藏」 in KaiTi calligraphy on rice paper (宣纸), surrounded by a
light-ink ensō brush ring, with a vermillion seal stamp 「經」 bottom-right.
Colors follow lib/core/ink/tokens/ink_tokens.dart (ink grades + sealRed).

Outputs (relative to flutter-app/):
  app-icons/ios/AppIcon.appiconset/   — full Apple HIG set + Contents.json
  app-icons/android/                  — Play Store 512, adaptive layers
                                        (foreground/background/monochrome),
                                        legacy launcher icons, anydpi-v26 XML

Specs:
  https://developer.apple.com/design/human-interface-guidelines/app-icons
  https://developer.android.com/distribute/google-play/resources/icon-design-specifications
"""

import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 2048  # master canvas, downscaled with Lanczos for every target size
RNG = np.random.default_rng(20260612)

KAITI = "C:/Windows/Fonts/simkai.ttf"

# Palette — warm neutral ink/paper, sealRed from InkTokens (hsl(10,58,47)).
PAPER_HI = (250, 246, 236)
PAPER_LO = (239, 232, 213)
INK_STRONG = (42, 37, 32)
INK_WASH = (74, 70, 62)
SEAL_RED = (189, 74, 50)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "app-icons"))
IOS_DIR = os.path.join(OUT, "ios", "AppIcon.appiconset")
AND_DIR = os.path.join(OUT, "android")


def noise_field(size, cell, lo=0.0, hi=1.0):
    """Smooth random field in [lo, hi] by upscaling low-res noise."""
    small = RNG.random((max(2, size // cell),) * 2).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8), "L")
    img = img.resize((size, size), Image.BICUBIC)
    return lo + (hi - lo) * (np.asarray(img, dtype=np.float32) / 255.0)


def paper_layer(size=S, vignette=0.06):
    """Rice paper: radial gradient + two-scale fiber noise + soft vignette."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx = cy = (size - 1) / 2
    r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size * 0.72)
    t = np.clip(r, 0, 1) ** 1.6
    base = np.empty((size, size, 3), np.float32)
    for i in range(3):
        base[..., i] = PAPER_HI[i] * (1 - t) + PAPER_LO[i] * t
    fiber = (noise_field(size, 4, -1, 1) * 3.0 +
             noise_field(size, 24, -1, 1) * 2.5)
    base += fiber[..., None]
    base *= (1 - vignette * np.clip(r, 0, 1) ** 2)[..., None]
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")


def enso_layer(size, center, radius, stroke, alpha=150):
    """Brush-drawn ink ring with a gap at the upper right, dry-brush texture
    and a blurred ink-bleed halo underneath."""
    layer = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(layer)
    start_deg, sweep = 118.0, 318.0  # gap ~42° centered near 67° (upper right)
    steps = int(2 * math.pi * radius * (sweep / 360) / 1.5)
    for i in range(steps + 1):
        t = i / steps
        ang = math.radians(start_deg + t * sweep)  # clockwise in screen coords
        # organic width modulation + tapered tail, slightly heavy entry
        w = stroke * (0.80 + 0.28 * math.sin(t * 6.1 + 1.2)
                      + 0.18 * math.sin(t * 13.7))
        if t > 0.86:
            w *= max(0.05, ((1 - t) / 0.14)) ** 0.75
        if t < 0.05:
            w *= 0.75 + 0.25 * (t / 0.05)
        rr = radius * (1 + 0.012 * math.sin(t * 4.4))
        x = center[0] + rr * math.cos(ang)
        y = center[1] - rr * math.sin(ang)
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)
    a = np.asarray(layer, np.float32) / 255.0
    a *= np.clip(0.40 + 0.85 * noise_field(size, 10), 0, 1)   # dry brush
    a *= np.clip(0.55 + 0.70 * noise_field(size, 48), 0, 1)   # ink pooling
    crisp = (a * alpha).astype(np.uint8)
    bleed = Image.fromarray((a * 70).astype(np.uint8), "L").filter(
        ImageFilter.GaussianBlur(size * 0.008))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (size, size), INK_WASH + (255,)), (0, 0), bleed)
    out.paste(Image.new("RGBA", (size, size), INK_WASH + (255,)), (0, 0),
              Image.fromarray(crisp, "L"))
    return out


def glyph_mask(size, ch, font_path, target_h, center):
    """Alpha mask of a single character with bbox height ≈ target_h."""
    fs = int(target_h)
    font = ImageFont.truetype(font_path, fs)
    l, t, r, b = font.getbbox(ch)
    fs = int(fs * target_h / max(1, b - t))
    font = ImageFont.truetype(font_path, fs)
    l, t, r, b = font.getbbox(ch)
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.text((center[0] - (l + r) / 2, center[1] - (t + b) / 2), ch,
           font=font, fill=255)
    return mask


def ink_glyph_layer(size, mask, color=INK_STRONG, bleed_blur=0.004):
    """Glyph with paper-absorption texture and soft ink bleed."""
    a = np.asarray(mask, np.float32) / 255.0
    a *= np.clip(0.90 + 0.14 * noise_field(size, 12), 0, 1)
    crisp = Image.fromarray((a * 255).astype(np.uint8), "L")
    bleed = mask.filter(ImageFilter.GaussianBlur(size * bleed_blur)).point(
        lambda v: int(v * 0.30))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (size, size), color + (255,)), (0, 0), bleed)
    out.paste(Image.new("RGBA", (size, size), color + (255,)), (0, 0), crisp)
    return out


def seal_layer(size, center, side, ch="經"):
    """Vermillion relief seal (朱文): red rounded square, white character,
    stamped-pad texture."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    half = side / 2
    box = [center[0] - half, center[1] - half, center[0] + half, center[1] + half]
    d.rounded_rectangle(box, radius=side * 0.10, fill=255)
    a = np.asarray(mask, np.float32) / 255.0
    a *= np.clip(0.82 + 0.26 * noise_field(size, 6), 0, 1)    # pad texture
    a *= np.clip(0.70 + 0.50 * noise_field(size, 28), 0, 1)   # uneven pressure
    seal = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    seal.paste(Image.new("RGBA", (size, size), SEAL_RED + (255,)), (0, 0),
               Image.fromarray((a * 255).astype(np.uint8), "L"))
    gm = glyph_mask(size, ch, KAITI, side * 0.66, center)
    ga = np.asarray(gm, np.float32) / 255.0
    ga *= np.clip(0.86 + 0.20 * noise_field(size, 8), 0, 1)
    seal.paste(Image.new("RGBA", (size, size), PAPER_HI + (255,)), (0, 0),
               Image.fromarray((ga * 235).astype(np.uint8), "L"))
    return seal


def compose_full(size=S):
    """Full-bleed square master (iOS all sizes, Play Store, legacy base).
    Key elements stay inside the central ~80% (HIG / Play safe margins)."""
    img = paper_layer(size).convert("RGBA")
    c = (size * 0.5, size * 0.485)
    img.alpha_composite(enso_layer(size, c, size * 0.358, size * 0.052))
    gm = glyph_mask(size, "藏", KAITI, size * 0.46, c)
    img.alpha_composite(ink_glyph_layer(size, gm))
    img.alpha_composite(seal_layer(size, (size * 0.745, size * 0.755),
                                   size * 0.165))
    return img


def compose_adaptive_fg(size=S):
    """Adaptive-icon foreground: transparent, all key content inside the
    66/108 dp safe-zone circle (Ø = 61.1% of canvas)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = (size * 0.5, size * 0.49)
    img.alpha_composite(enso_layer(size, c, size * 0.252, size * 0.036,
                                   alpha=135))
    gm = glyph_mask(size, "藏", KAITI, size * 0.325, c)
    img.alpha_composite(ink_glyph_layer(size, gm, bleed_blur=0.003))
    img.alpha_composite(seal_layer(size, (size * 0.662, size * 0.668),
                                   size * 0.118))
    return img


def compose_adaptive_bg(size=S):
    """Adaptive-icon background: plain rice paper (safe under any mask)."""
    return paper_layer(size, vignette=0.04).convert("RGBA")


def compose_monochrome(size=S):
    """Android 13+ themed-icon layer: single glyph, white alpha mask,
    sized for the same safe zone as the foreground."""
    gm = glyph_mask(size, "藏", KAITI, size * 0.40,
                    (size * 0.5, size * 0.49))
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (size, size), (255, 255, 255, 255)), (0, 0), gm)
    return img


def rounded(img, radius_frac):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=int(img.size[0] * radius_frac), fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def circular(img):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, img.size[0] - 1, img.size[1] - 1],
                                 fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def save(img, path, px, opaque=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    small = img.resize((px, px), Image.LANCZOS)
    if opaque:
        small = small.convert("RGB")
    small.save(path, "PNG")


# ---------------------------------------------------------------- iOS -------
IOS_ICONS = [
    # (idiom, size_pt, scale)
    ("iphone", 20, 2), ("iphone", 20, 3),
    ("iphone", 29, 1), ("iphone", 29, 2), ("iphone", 29, 3),
    ("iphone", 40, 2), ("iphone", 40, 3),
    ("iphone", 60, 2), ("iphone", 60, 3),
    ("ipad", 20, 1), ("ipad", 20, 2),
    ("ipad", 29, 1), ("ipad", 29, 2),
    ("ipad", 40, 1), ("ipad", 40, 2),
    ("ipad", 76, 1), ("ipad", 76, 2),
    ("ipad", 83.5, 2),
    ("ios-marketing", 1024, 1),
]


def fmt_pt(v):
    return f"{v:g}"


def build_ios(master):
    entries = []
    for idiom, pt, scale in IOS_ICONS:
        px = int(round(pt * scale))
        name = f"Icon-App-{fmt_pt(pt)}x{fmt_pt(pt)}@{scale}x.png"
        # HIG: full-bleed square, no pre-rounded corners, no transparency.
        save(master, os.path.join(IOS_DIR, name), px, opaque=True)
        entries.append({
            "size": f"{fmt_pt(pt)}x{fmt_pt(pt)}",
            "idiom": idiom,
            "filename": name,
            "scale": f"{scale}x",
        })
    contents = {"images": entries,
                "info": {"version": 1, "author": "xcode"}}
    with open(os.path.join(IOS_DIR, "Contents.json"), "w",
              encoding="utf-8") as f:
        json.dump(contents, f, indent=2)


# ------------------------------------------------------------- Android ------
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

LAUNCHER_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
"""


def build_android(master, fg, bg, mono):
    res = os.path.join(AND_DIR, "res")
    # Google Play listing icon: 512×512, 32-bit PNG, full square (Play
    # applies the rounding + drop shadow), ≤ 1 MB.
    save(master, os.path.join(AND_DIR, "play-store",
                              "ic_launcher_512.png"), 512, opaque=True)
    for dpi, mult in DENSITIES.items():
        mip = os.path.join(res, f"mipmap-{dpi}")
        # Adaptive layers: 108dp per density.
        adp = int(108 * mult)
        save(fg, os.path.join(mip, "ic_launcher_foreground.png"), adp)
        save(bg, os.path.join(mip, "ic_launcher_background.png"), adp)
        save(mono, os.path.join(mip, "ic_launcher_monochrome.png"), adp)
        # Legacy launcher (API < 26): 48dp, shape baked in.
        leg = int(48 * mult)
        save(rounded(master, 0.10), os.path.join(mip, "ic_launcher.png"), leg)
        save(circular(master), os.path.join(mip, "ic_launcher_round.png"), leg)
    v26 = os.path.join(res, "mipmap-anydpi-v26")
    os.makedirs(v26, exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(v26, name), "w", encoding="utf-8") as f:
            f.write(LAUNCHER_XML)


def main():
    print("composing masters (2048px)...")
    master = compose_full()
    fg = compose_adaptive_fg()
    bg = compose_adaptive_bg()
    mono = compose_monochrome()
    os.makedirs(OUT, exist_ok=True)
    master.resize((1024, 1024), Image.LANCZOS).save(
        os.path.join(OUT, "preview_full_1024.png"))
    print("building iOS set...")
    build_ios(master)
    print("building Android set...")
    build_android(master, fg, bg, mono)
    print("done ->", OUT)


if __name__ == "__main__":
    main()
