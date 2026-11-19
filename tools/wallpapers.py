#!/usr/bin/env python3
"""Draws ansai-shell's wallpapers: three designs, each as -light and -dark (the shell swaps the pair
when the theme changes). Run: python3 tools/wallpapers.py  -> quickshell/assets/wallpapers/*.jpg"""
import os
import numpy as np
from PIL import Image

W, H = 2880, 1800
OUT = os.path.join(os.path.dirname(__file__), "..", "quickshell", "assets", "wallpapers")
rng = np.random.default_rng(7)
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = x / W, y / H  # 0..1


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def save(img, name):
    img = img + rng.normal(0, 1.6, img.shape).astype(np.float32)  # grain: no banding
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + ".jpg"), quality=90, optimize=True)
    print("wrote", name)


def drift(dark):
    """Soft mesh gradient: big blurred colour fields drifting into each other."""
    base = hexc("#0a0f1f" if dark else "#f3f5fb")
    blobs = [  # u, v, radius, colour, strength
        (0.18, 0.25, 0.42, "#2f6bff" if dark else "#7fa9ff", 1.3 if dark else 1.8),
        (0.55, 0.10, 0.35, "#7b3cff" if dark else "#c8a8ff", 1.1),
        (0.85, 0.45, 0.40, "#ff4fa3" if dark else "#ffa3c6", 1.2 if dark else 1.7),
        (0.40, 0.85, 0.45, "#12b8a6" if dark else "#9ee9dc", 1.1),
        (0.95, 0.95, 0.30, "#ff9f43" if dark else "#ffd6a8", 0.8),
    ]
    acc = np.zeros((H, W, 3), np.float32)
    wsum = np.zeros((H, W, 1), np.float32)
    for bu, bv, r, c, s in blobs:
        d2 = ((u - bu) * W / H) ** 2 + (v - bv) ** 2
        w = (s * np.exp(-d2 / (2 * (r * 0.55) ** 2)))[..., None]
        acc += w * hexc(c)
        wsum += w
    img = (base + acc) / (1 + wsum)
    vign = 1 - (0.35 if dark else 0.06) * (((u - 0.5) ** 2 + (v - 0.5) ** 2) * 2)[..., None]
    save(img * vign, f"drift-{'dark' if dark else 'light'}")


def ribbons(dark):
    """Glossy ribbons of colour sweeping across the screen."""
    top, bottom = (hexc("#0b0d1a"), hexc("#141433")) if dark else (hexc("#fbfbfe"), hexc("#eef0f8"))
    img = top + (bottom - top) * v[..., None]
    specs = [  # y0, amplitude, freq, phase, thickness, colour a, colour b
        (0.62, 0.10, 5.2, 0.4, 0.060, "#3a7bff", "#9b5cff"),
        (0.55, 0.12, 4.1, 1.9, 0.045, "#ff5fa2", "#ffb36b"),
        (0.70, 0.08, 6.0, 3.1, 0.035, "#2ed3c1", "#3a7bff"),
        (0.48, 0.09, 3.3, 4.4, 0.028, "#b46bff", "#ff6b9a"),
    ]
    for y0, a, f, ph, t, ca, cb in specs:
        yc = y0 + a * np.sin(f * u + ph) + 0.03 * np.sin(2.3 * f * u + ph * 1.7)
        d = (v - yc) / t
        body = np.exp(-d ** 2)
        shine = np.exp(-((d + 0.55) / 0.18) ** 2) * 0.55  # thin highlight along the top edge
        col = hexc(ca) + (hexc(cb) - hexc(ca)) * u[..., None]
        if not dark:
            col = col * 0.85 + 255 * 0.15
        k = (body * (0.9 if dark else 0.75))[..., None]
        img = img * (1 - k) + col * k
        img = img + (shine * (255 if dark else 140))[..., None] * body[..., None] ** 0.3
    save(img, f"ribbons-{'dark' if dark else 'light'}")


def dunes(dark):
    """Layered hills under a soft glow, like dusk (dark) or morning (light)."""
    sky_top, sky_bot = (hexc("#0d1030"), hexc("#3b2a6b")) if dark else (hexc("#cfe3ff"), hexc("#ffe9d6"))
    img = sky_top + (sky_bot - sky_top) * (v ** 0.9)[..., None]
    gu, gv = 0.68, 0.42
    glow = np.exp(-(((u - gu) * W / H) ** 2 + (v - gv) ** 2) / (2 * 0.16 ** 2))[..., None]
    img = img + glow * (hexc("#ff8a5c") if dark else hexc("#fff3c4")) * (0.55 if dark else 0.28)
    layers = (["#2a1f5c", "#3d2a7a", "#5a2f8a", "#7a3a8f", "#1a1440"] if dark
              else ["#b9cdf7", "#a4b8f0", "#f2b8c6", "#e99aae", "#8f83c9"])
    for i, c in enumerate(layers):
        base = 0.55 + i * 0.09
        ycurve = base + 0.05 * np.sin(2.1 * u * np.pi + i * 1.3) + 0.025 * np.sin(5.3 * u * np.pi + i * 2.1)
        edge = np.clip((v - ycurve) * H / 2.0, 0, 1)[..., None]  # antialiased hill edge
        shade = hexc(c) * (1 - 0.18 * (v - ycurve).clip(0, 1)[..., None] * 2)
        img = img * (1 - edge) + shade * edge
    save(img, f"dunes-{'dark' if dark else 'light'}")


os.makedirs(OUT, exist_ok=True)
for dark in (False, True):
    drift(dark)
    ribbons(dark)
    dunes(dark)
