"""
make_colored_shapes.py

Builds the colored critical-distractor shapes from the black shapes.

The three colors have the same lightness (CIE L*) and the same chroma, and
their hues are 120 degrees apart in CIELAB, so they differ only in hue.
Each black shape (stimuli/shapes/Black_Left_T, Black_Right_T) is recolored:
black becomes the color, the white T stays white, transparency is unchanged.

NOTE: "same luminance" assumes a standard sRGB monitor. On an uncalibrated
display the three colors will be close but not exactly equal; measure them
with a photometer and adjust LIGHTNESS per color if exact equality matters.

Usage (from the repository root):
    python3 setup/make_colored_shapes.py

Output: stimuli/shapes/<Name>_Left_T and <Name>_Right_T for each color,
        with files named like Shape10_L_<Name>.png
"""

import os
import re

import cv2
import numpy as np

# ---------------------------------------------------------------- settings
LIGHTNESS = 65.0      # CIE L* (0 = black, 100 = white); the old colors were 47-54
FIRST_HUE = 40.0      # CIELAB hue angle of the first color; the others are +120 and +240
COLOR_NAMES = ["Coral", "SeaGreen", "SkyBlue"]   # color code 1, 2, 3 in the experiment

SHAPE_DIR = os.path.join("stimuli", "shapes")

# ---------------------------------------------------------------- color math (sRGB, D65)
RGB_TO_XYZ = np.array([[0.4124564, 0.3575761, 0.1804375],
                       [0.2126729, 0.7151522, 0.0721750],
                       [0.0193339, 0.1191920, 0.9503041]])
XYZ_TO_RGB = np.linalg.inv(RGB_TO_XYZ)
WHITE = RGB_TO_XYZ.sum(axis=1)


def lch_to_linear_rgb(lightness, chroma, hue):
    a = chroma * np.cos(np.radians(hue))
    b = chroma * np.sin(np.radians(hue))
    fy = (lightness + 16) / 116
    f = np.array([fy + a / 500, fy, fy - b / 200])
    xyz = np.where(f > 6 / 29, f ** 3, 3 * (6 / 29) ** 2 * (f - 4 / 29)) * WHITE
    return XYZ_TO_RGB @ xyz


def linear_to_srgb255(linear):
    linear = np.clip(linear, 0, 1)
    encoded = np.where(linear <= 0.0031308, 12.92 * linear, 1.055 * linear ** (1 / 2.4) - 0.055)
    return np.round(encoded * 255).astype(int)


def srgb255_to_lch(rgb):
    c = np.asarray(rgb, float) / 255
    linear = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    t = (RGB_TO_XYZ @ linear) / WHITE
    f = np.where(t > (6 / 29) ** 3, np.cbrt(t), t / (3 * (6 / 29) ** 2) + 4 / 29)
    lightness, a, b = 116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])
    return lightness, np.hypot(a, b), np.degrees(np.arctan2(b, a)) % 360


def max_chroma(lightness, hue):
    """Largest chroma a monitor can show at this lightness and hue."""
    low, high = 0.0, 150.0
    for _ in range(40):
        middle = (low + high) / 2
        linear = lch_to_linear_rgb(lightness, middle, hue)
        if linear.min() >= 0 and linear.max() <= 1:
            low = middle
        else:
            high = middle
    return low


# ---------------------------------------------------------------- pick the colors
hues = [(FIRST_HUE + 120 * k) % 360 for k in range(3)]
chroma = min(max_chroma(LIGHTNESS, hue) for hue in hues)   # most saturated value all three can reach
colors = [linear_to_srgb255(lch_to_linear_rgb(LIGHTNESS, chroma, hue)) for hue in hues]

print(f"L* = {LIGHTNESS}, chroma = {chroma:.1f}, hues = {hues}")
for name, rgb in zip(COLOR_NAMES, colors):
    lightness, c, h = srgb255_to_lch(rgb)
    print(f"  {name:9s} RGB = {tuple(int(v) for v in rgb)}   (after rounding: L* = {lightness:.1f}, "
          f"chroma = {c:.1f}, hue = {h:.0f})")

# ---------------------------------------------------------------- recolor the shapes
for side, letter in (("Left", "L"), ("Right", "R")):
    source_dir = os.path.join(SHAPE_DIR, f"Black_{side}_T")
    files = [f for f in os.listdir(source_dir) if f.lower().endswith(".png")]
    for name, rgb in zip(COLOR_NAMES, colors):
        out_dir = os.path.join(SHAPE_DIR, f"{name}_{side}_T")
        os.makedirs(out_dir, exist_ok=True)
        for file in files:
            image = cv2.imread(os.path.join(source_dir, file), cv2.IMREAD_UNCHANGED)   # BGRA
            gray = image[:, :, :1].astype(np.float32) / 255.0        # 0 = black body, 1 = white T
            bgr = np.array(rgb[::-1], dtype=np.float32)
            recolored = bgr + (255.0 - bgr) * gray
            out = np.dstack([np.round(recolored).astype(np.uint8), image[:, :, 3]])
            number = re.search(r"Shape(\d+)", file).group(1)
            cv2.imwrite(os.path.join(out_dir, f"Shape{number}_{letter}_{name}.png"), out)
        print(f"wrote {len(files)} shapes to {out_dir}")
