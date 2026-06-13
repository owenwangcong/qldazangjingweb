# -*- coding: utf-8 -*-
"""Google Play feature graphic for 乾隆大藏经 (ink-wash design language).

Spec (https://support.google.com/googleplay/android-developer/answer/9866151):
  - 1024 x 500 px, JPEG or 24-bit PNG, no alpha, <= 15 MB.
  - Important content kept off the dead-center (a play-button overlay may
    cover it when a promo video is present) and away from the edges.

Composition: the 藏 ensō emblem (reused from the app icon) sits left-of-
center on rice paper; the title 「乾隆大藏经」, a hairline rule, a tagline and
a latin subtitle stack on the right. The center gutter is left as clean
paper so a play button overlays nothing important.

Shares palette / font / texture approach with generate_app_icons.py.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from generate_app_icons import (
    PAPER_HI, PAPER_LO, INK_STRONG, INK_WASH, SEAL_RED, KAITI,
)

ARIAL = "C:/Windows/Fonts/arial.ttf"

SS = 2  # supersample factor; master rendered at 2x then Lanczos-downscaled
W, H = 1024 * SS, 500 * SS

rng = np.random.default_rng(20260612)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "app-icons", "android",
                                    "play-store"))


def px(v):
    return int(round(v * SS))


def noise_field(w, h, cell, lo=0.0, hi=1.0):
    small = rng.random((max(2, h // cell), max(2, w // cell))).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8), "L").resize(
        (w, h), Image.BICUBIC)
    return lo + (hi - lo) * (np.asarray(img, np.float32) / 255.0)


def paper_layer():
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = (W - 1) / 2, (H - 1) / 2
    r = np.sqrt(((xx - cx) / (W * 0.60)) ** 2 + ((yy - cy) / (H * 0.62)) ** 2)
    t = np.clip(r, 0, 1) ** 1.5
    base = np.empty((H, W, 3), np.float32)
    for i in range(3):
        base[..., i] = PAPER_HI[i] * (1 - t) + PAPER_LO[i] * t
    fiber = noise_field(W, H, 4, -1, 1) * 3.0 + noise_field(W, H, 28, -1, 1) * 2.4
    base += fiber[..., None]
    base *= (1 - 0.05 * np.clip(r, 0, 1) ** 2)[..., None]
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def enso(center, radius, stroke, alpha=150):
    layer = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(layer)
    start_deg, sweep = 118.0, 318.0
    steps = int(2 * math.pi * radius * (sweep / 360) / 1.5)
    for i in range(steps + 1):
        t = i / steps
        ang = math.radians(start_deg + t * sweep)
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
    a *= np.clip(0.40 + 0.85 * noise_field(W, H, 10), 0, 1)
    a *= np.clip(0.55 + 0.70 * noise_field(W, H, 48), 0, 1)
    crisp = (a * alpha).astype(np.uint8)
    bleed = Image.fromarray((a * 70).astype(np.uint8), "L").filter(
        ImageFilter.GaussianBlur(radius * 0.022))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (W, H), INK_WASH + (255,)), (0, 0), bleed)
    out.paste(Image.new("RGBA", (W, H), INK_WASH + (255,)), (0, 0),
              Image.fromarray(crisp, "L"))
    return out


def glyph_mask(ch, target_h, center):
    fs = int(target_h)
    font = ImageFont.truetype(KAITI, fs)
    l, t, r, b = font.getbbox(ch)
    fs = int(fs * target_h / max(1, b - t))
    font = ImageFont.truetype(KAITI, fs)
    l, t, r, b = font.getbbox(ch)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).text(
        (center[0] - (l + r) / 2, center[1] - (t + b) / 2), ch,
        font=font, fill=255)
    return mask


def ink_from_mask(mask, color=INK_STRONG, bleed_blur=6, tex_cell=12,
                  tex_amt=0.14, base=0.90):
    a = np.asarray(mask, np.float32) / 255.0
    a *= np.clip(base + tex_amt * noise_field(W, H, tex_cell), 0, 1)
    crisp = Image.fromarray((a * 255).astype(np.uint8), "L")
    bleed = mask.filter(ImageFilter.GaussianBlur(bleed_blur)).point(
        lambda v: int(v * 0.30))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (W, H), color + (255,)), (0, 0), bleed)
    out.paste(Image.new("RGBA", (W, H), color + (255,)), (0, 0), crisp)
    return out


def cjk_text_mask(text, font_px, center, tracking):
    font = ImageFont.truetype(KAITI, font_px)
    advs = [font.getlength(c) + tracking for c in text]
    total = sum(advs) - tracking
    x = center[0] - total / 2
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    for c, a in zip(text, advs):
        d.text((x + (a - tracking) / 2, center[1]), c, font=font, fill=255,
               anchor="mm")
        x += a
    return mask


def latin_text(text, font_px, center, tracking, color, alpha):
    font = ImageFont.truetype(ARIAL, font_px)
    advs = [font.getlength(c) + tracking for c in text]
    total = sum(advs) - tracking
    x = center[0] - total / 2
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    for c, a in zip(text, advs):
        d.text((x + (a - tracking) / 2, center[1]), c, font=font, fill=alpha,
               anchor="mm")
        x += a
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (W, H), color + (255,)), (0, 0), mask)
    return out


def seal(center, side, ch="經"):
    mask = Image.new("L", (W, H), 0)
    half = side / 2
    ImageDraw.Draw(mask).rounded_rectangle(
        [center[0] - half, center[1] - half, center[0] + half, center[1] + half],
        radius=side * 0.10, fill=255)
    a = np.asarray(mask, np.float32) / 255.0
    a *= np.clip(0.82 + 0.26 * noise_field(W, H, 6), 0, 1)
    a *= np.clip(0.70 + 0.50 * noise_field(W, H, 28), 0, 1)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (W, H), SEAL_RED + (255,)), (0, 0),
              Image.fromarray((a * 255).astype(np.uint8), "L"))
    gm = glyph_mask(ch, side * 0.66, center)
    ga = np.asarray(gm, np.float32) / 255.0
    ga *= np.clip(0.86 + 0.20 * noise_field(W, H, 8), 0, 1)
    out.paste(Image.new("RGBA", (W, H), PAPER_HI + (255,)), (0, 0),
              Image.fromarray((ga * 235).astype(np.uint8), "L"))
    return out


def hairline(x0, x1, y, weight, color, alpha):
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).line([(x0, y), (x1, y)], fill=alpha, width=max(1, weight))
    a = np.asarray(mask, np.float32) / 255.0
    a *= np.clip(0.6 + 0.6 * noise_field(W, H, 20), 0, 1)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (W, H), color + (255,)), (0, 0),
              Image.fromarray((a * 255).astype(np.uint8), "L"))
    return out


def compose():
    img = paper_layer()

    # faint oversized watermark ensō spanning the title block (balance + depth)
    img.alpha_composite(enso((px(700), px(250)), px(232), px(20), alpha=16))

    # --- left emblem ---------------------------------------------------------
    ec = (px(252), px(250))
    img.alpha_composite(enso(ec, px(150), px(25), alpha=152))
    img.alpha_composite(ink_from_mask(glyph_mask("藏", px(196), ec),
                                      bleed_blur=px(2)))
    img.alpha_composite(seal((px(338), px(338)), px(74)))

    # --- right text block ----------------------------------------------------
    tcx = px(700)
    img.alpha_composite(ink_from_mask(
        cjk_text_mask("乾隆大藏经", px(96), (tcx, px(172)), px(16)),
        bleed_blur=px(1.6), tex_amt=0.12))
    img.alpha_composite(hairline(px(540), px(860), px(248), px(2),
                                 INK_WASH, 150))
    # seal-red accent dot on the rule
    img.alpha_composite(ink_from_mask(
        cjk_text_mask("·", px(40), (px(700), px(247)), 0),
        color=SEAL_RED, bleed_blur=px(1)))
    img.alpha_composite(ink_from_mask(
        cjk_text_mask("数字大藏经 · 离线研读", px(40), (tcx, px(300)), px(8)),
        color=INK_WASH, bleed_blur=px(1.2), tex_amt=0.10, base=0.94))
    img.alpha_composite(latin_text("QIANLONG  TRIPITAKA", px(26),
                                   (tcx, px(356)), px(6), INK_WASH, 165))

    return img.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    master = compose()
    final = master.resize((1024, 500), Image.LANCZOS)
    png_path = os.path.join(OUT, "feature_graphic_1024x500.png")
    jpg_path = os.path.join(OUT, "feature_graphic_1024x500.jpg")
    final.save(png_path, "PNG")           # 24-bit, no alpha
    final.save(jpg_path, "JPEG", quality=92)
    print("saved:", png_path)
    print("saved:", jpg_path)

    # QA overlay: simulate the centered play-button to confirm nothing
    # important is occluded.
    qa = final.copy()
    d = ImageDraw.Draw(qa, "RGBA")
    cx, cy, rr = 512, 250, 58
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(0, 0, 0, 90))
    d.polygon([(cx - 18, cy - 26), (cx - 18, cy + 26), (cx + 28, cy)],
              fill=(255, 255, 255, 220))
    qa.save(os.path.join(OUT, "_qa_playbutton.png"))


if __name__ == "__main__":
    main()
