"""
distractor_saliency_check.py

Is the colored (critical) distractor actually salient in the search displays?

For a random sample of distractor-present trials that participants really saw,
this script re-renders the search display (scene + the six shapes, exactly as
region_suppression.m drew them), runs GBVS on it, and measures the saliency
at each shape. Every display is rendered twice:
    - "color":   as shown in the experiment
    - "black":   identical, but the critical distractor is drawn in black
so the gain in saliency from the color alone can be measured at the same
location, in the same scene, with the same shape.

Usage (must be run from the scene_color_correction folder, because GBVS loads
its resources with a relative path):
    cd scene_color_correction
    python3 distractor_saliency_check.py            # 300 trials
    python3 distractor_saliency_check.py 600        # more trials

Outputs (scene_color_correction/output/saliency_check/):
    saliency_results.csv   one row per sampled trial
    rendered/              the rendered displays (as shown in the experiment)
    overlays/              a few displays with their GBVS map, for eyeballing

Measures
    *_pct      : percentile of the shape's mean saliency within its own display
                 (0-100; 50 = an average patch of the scene)
    crit_rank  : rank of the critical distractor among the 6 shapes (1 = most salient)
"""

import glob
import os
import re
import sys

import cv2
import numpy as np
import pandas as pd
import scipy.io as sio

from saliency_models import gbvs

# ---------------------------------------------------------------- settings
N_TRIALS = int(sys.argv[1]) if len(sys.argv) > 1 else 300
SEED = 2026
SCREEN_W, SCREEN_H = 1920, 1080
N_OVERLAYS = 12

REPO = os.path.abspath("..")
BX_DIR = os.path.join(REPO, "data", "bx_data")
MAT_DIR = os.path.join(REPO, "data", "MAT_data")
SHAPE_DIR = os.path.join(REPO, "stimuli", "shapes")
OUT_DIR = os.path.join("output", "saliency_check")

# color code -> what region_suppression.m actually draws
COLOR_NAMES = {1: "Mag", 2: "Green", 3: "Blue"}


# ---------------------------------------------------------------- helpers
_shape_files = {}


def shape_files(folder):
    """Files of one shape folder sorted by the number in their name, like image_stimuli_import(..., true).
    The experiment's shape index (1-22) is the position in this sorted list, NOT the number in the
    file name (the files are numbered 1-24 with 3 and 7 missing)."""
    if folder not in _shape_files:
        names = [f for f in os.listdir(os.path.join(SHAPE_DIR, folder)) if f.lower().endswith(".png")]
        names.sort(key=lambda f: int(re.search(r"Shape(\d+)", f).group(1)))
        _shape_files[folder] = names
    return _shape_files[folder]


def load_shape(index, direction, color=None):
    """index: 1-22 (texture index used by the experiment), direction: 0 = left T, 1 = right T,
    color: None (black) / 'Mag' / 'Green' / 'Blue'."""
    side = "Left" if direction == 0 else "Right"
    folder = f"{'Black' if color is None else color}_{side}_T"
    path = os.path.join(SHAPE_DIR, folder, shape_files(folder)[index - 1])
    img = cv2.imread(path, cv2.IMREAD_UNCHANGED)   # BGRA
    if img is None or img.ndim != 3 or img.shape[2] != 4:
        raise FileNotFoundError(f"Could not read RGBA shape: {path}")
    return img


def draw_shape(canvas, shape, rect):
    """Alpha-blend a shape into rect = [left, top, right, bottom] (like Screen('DrawTexture'))."""
    left, top, right, bottom = [int(round(v)) for v in rect]
    shape = cv2.resize(shape, (right - left, bottom - top), interpolation=cv2.INTER_AREA)
    alpha = shape[:, :, 3:4].astype(np.float32) / 255.0
    region = canvas[top:bottom, left:right].astype(np.float32)
    canvas[top:bottom, left:right] = (alpha * shape[:, :, :3] + (1 - alpha) * region).astype(np.uint8)


def rect_of(row, prefix):
    values = [row.get(f"{prefix}_{i}") for i in range(1, 5)]
    if any(pd.isna(v) for v in values):
        return None
    return [float(v) for v in values]


def render_trial(row, t_dirs, colored):
    """Rebuild the search display for one trial. t_dirs: that trial's row of t_directions."""
    scene = cv2.imread(os.path.join(REPO, row["scene_file"].replace("\\", "/")))
    if scene is None:
        raise FileNotFoundError(row["scene_file"])
    canvas = cv2.resize(scene, (SCREEN_W, SCREEN_H), interpolation=cv2.INTER_AREA)

    # target: T direction is column 1
    draw_shape(canvas, load_shape(int(row["target_shape_idx"]), int(t_dirs[0])), rect_of(row, "target_rect"))
    # critical distractor: T direction is column 6
    color = COLOR_NAMES[int(row["color"])] if colored else None
    draw_shape(canvas, load_shape(int(row["critical_distractor_idx"]), int(t_dirs[5]), color),
               rect_of(row, "critical_distractor_rect"))
    # non-critical distractors: k-th one uses T direction column 1 + k
    for k in range(1, 6):
        rect = rect_of(row, f"noncritical_distractor_rect{k}")
        if rect is not None:
            draw_shape(canvas, load_shape(int(row[f"noncritical_distractor_idx{k}"]), int(t_dirs[k])), rect)
    return canvas


def region_percentile(sal_map, rect):
    """Percentile (0-100) of the mean saliency inside rect, relative to all pixels of the map."""
    left, top, right, bottom = [int(round(v)) for v in rect]
    value = sal_map[top:bottom, left:right].mean()
    return 100.0 * (sal_map < value).mean()


def item_percentiles(sal_map, row):
    out = {"target_pct": region_percentile(sal_map, rect_of(row, "target_rect")),
           "crit_pct": region_percentile(sal_map, rect_of(row, "critical_distractor_rect"))}
    noncrit = [region_percentile(sal_map, rect_of(row, f"noncritical_distractor_rect{k}"))
               for k in range(1, 6) if rect_of(row, f"noncritical_distractor_rect{k}") is not None]
    out["noncrit_mean_pct"] = float(np.mean(noncrit))
    all_items = [out["target_pct"], out["crit_pct"]] + noncrit
    out["crit_rank"] = 1 + sum(v > out["crit_pct"] for v in all_items)
    out["n_items"] = len(all_items)
    return out


# ---------------------------------------------------------------- load trials
frames = []
for path in sorted(glob.glob(os.path.join(BX_DIR, "*.csv"))):
    frame = pd.read_csv(path)
    frame["bx_file"] = os.path.basename(path)
    frames.append(frame)
trials = pd.concat(frames, ignore_index=True)

trials = trials[(trials["run_num"] != 1) & (trials["condition"] != 0) & trials["color"].notna()
                & (trials["sub_num"] < 100)]          # main runs, distractor present, no pilot subjects
trials = trials.sample(n=min(N_TRIALS, len(trials)), random_state=SEED).reset_index(drop=True)
print(f"Sampled {len(trials)} distractor-present trials from {trials['sub_num'].nunique()} subjects")

os.makedirs(os.path.join(OUT_DIR, "rendered"), exist_ok=True)
os.makedirs(os.path.join(OUT_DIR, "overlays"), exist_ok=True)

# ---------------------------------------------------------------- render + GBVS
t_direction_cache = {}
results = []
for i, row in trials.iterrows():
    sub, run, trial = int(row["sub_num"]), int(row["run_num"]), int(row["trial_num"])
    key = (sub, run)
    if key not in t_direction_cache:
        mat = sio.loadmat(os.path.join(MAT_DIR, f"Subj{sub}Run{run:02d}.mat"), variable_names=["t_directions"])
        t_direction_cache[key] = mat["t_directions"]
    t_dirs = t_direction_cache[key][trial - 1]
    if int(t_dirs[0]) != int(row["t_direction"]):
        raise ValueError(f"T direction mismatch for subject {sub} run {run} trial {trial}")

    record = {"sub_num": sub, "run_num": run, "trial_num": trial, "scene_idx": int(row["scene_idx"]),
              "condition": int(row["condition"]), "color": COLOR_NAMES[int(row["color"])]}
    for version in ("color", "black"):
        display = render_trial(row, t_dirs, colored=(version == "color"))
        sal_map = gbvs.compute_saliency(display)
        for name, value in item_percentiles(sal_map, row).items():
            record[f"{version}_{name}"] = value
        if version == "color":
            name = f"sub{sub:02d}_run{run}_trial{trial:02d}"
            cv2.imwrite(os.path.join(OUT_DIR, "rendered", name + ".jpg"), display, [cv2.IMWRITE_JPEG_QUALITY, 88])
            if i < N_OVERLAYS:
                heat = cv2.applyColorMap(np.clip(sal_map, 0, 255).astype(np.uint8), cv2.COLORMAP_JET)
                overlay = cv2.addWeighted(display, 0.5, heat, 0.5, 0)
                left, top, right, bottom = [int(round(v)) for v in rect_of(row, "critical_distractor_rect")]
                cv2.rectangle(overlay, (left - 6, top - 6), (right + 6, bottom + 6), (255, 255, 255), 3)
                cv2.imwrite(os.path.join(OUT_DIR, "overlays", name + "_gbvs.jpg"), overlay, [cv2.IMWRITE_JPEG_QUALITY, 88])
    results.append(record)
    if (i + 1) % 25 == 0:
        print(f"  {i + 1}/{len(trials)}", flush=True)

results = pd.DataFrame(results)
results["color_gain_pct"] = results["color_crit_pct"] - results["black_crit_pct"]
results.to_csv(os.path.join(OUT_DIR, "saliency_results.csv"), index=False)

# ---------------------------------------------------------------- summary
pd.set_option("display.width", 200)
print("\n===== Saliency percentile within the display (50 = average patch of the scene) =====")
print(results[["color_crit_pct", "black_crit_pct", "color_noncrit_mean_pct", "color_target_pct"]]
      .describe().loc[["mean", "50%", "25%", "75%"]].round(1))

print("\n===== Gain from color at the same location (colored minus black version) =====")
gain = results["color_gain_pct"]
print(f"mean gain = {gain.mean():.1f} percentile points, median = {gain.median():.1f}, "
      f"colored more salient than black in {100 * (gain > 0).mean():.0f}% of displays")

print("\n===== Rank of the critical distractor among the 6 shapes (1 = most salient) =====")
for version in ("color", "black"):
    rank = results[f"{version}_crit_rank"]
    print(f"{version:5s}: most salient shape in {100 * (rank == 1).mean():.0f}% of displays "
          f"(chance = 17%), mean rank = {rank.mean():.2f} (chance = 3.5)")

print("\n===== By color =====")
print(results.groupby("color").agg(n=("color_crit_pct", "size"),
                                   colored_pct=("color_crit_pct", "mean"),
                                   black_pct=("black_crit_pct", "mean"),
                                   gain=("color_gain_pct", "mean"),
                                   most_salient=("color_crit_rank", lambda r: 100 * (r == 1).mean())).round(1))

print("\n===== By condition (1 = high-probability, 2/3 = low-probability) =====")
results["location"] = np.where(results["condition"] == 1, "High", "Low")
print(results.groupby("location").agg(n=("color_crit_pct", "size"),
                                      colored_pct=("color_crit_pct", "mean"),
                                      gain=("color_gain_pct", "mean"),
                                      most_salient=("color_crit_rank", lambda r: 100 * (r == 1).mean())).round(1))
print(f"\nSaved: {os.path.join(OUT_DIR, 'saliency_results.csv')}")
