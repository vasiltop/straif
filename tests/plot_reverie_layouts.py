#!/usr/bin/env python3
"""Render top-down example-map galleries from real generator output.

Reads tests/reverie_layouts.json (produced by tests/dump_reverie_layouts.gd)
and writes one top-down PNG per seed to images/procedural_examples/. Each block
is drawn as a rectangle at its XZ footprint, colored by height (Y), with the
path traced through the block centers. The spawn platform is drawn in grey.
"""
import json
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.collections import PatchCollection

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tests", "reverie_layouts.json")
OUT = os.path.join(ROOT, "images", "procedural_examples")

os.makedirs(OUT, exist_ok=True)

with open(DATA) as fh:
    layouts = json.load(fh)

# Pink dreamscape palette.
BG = "#1a0f1f"
PATH = "#ff9fe5"
SPAWN = "#6a5570"

for seed in sorted(layouts.keys(), key=lambda s: int(s)):
    blocks = layouts[seed]
    ys = [b["y"] for b in blocks[1:]]
    ymin, ymax = min(ys), max(ys)
    yspan = (ymax - ymin) or 1.0

    fig, ax = plt.subplots(figsize=(8, 8))
    fig.patch.set_facecolor(BG)
    ax.set_facecolor(BG)

    rects = []
    colors = []
    for idx, b in enumerate(blocks):
        x, z = b["x"], b["z"]
        sx, sz = b["sx"], b["sz"]
        rect = Rectangle((x - sx / 2.0, z - sz / 2.0), sx, sz)
        rects.append(rect)
        if idx == 0:
            colors.append(SPAWN)
        else:
            t = (b["y"] - ymin) / yspan
            # magma-ish pink->violet ramp by height
            colors.append(plt.cm.magma(0.35 + 0.5 * t))

    pc = PatchCollection(rects, facecolor=colors, edgecolor="#ffffff22", linewidths=0.4)
    ax.add_collection(pc)

    px = [b["x"] for b in blocks[1:]]
    pz = [b["z"] for b in blocks[1:]]
    ax.plot(px, pz, color=PATH, linewidth=1.2, alpha=0.8, zorder=5)
    ax.scatter(px[:1], pz[:1], color="#ffffff", s=30, zorder=6, label="start")

    allx = [b["x"] for b in blocks]
    allz = [b["z"] for b in blocks]
    pad = 6.0
    ax.set_xlim(min(allx) - pad, max(allx) + pad)
    ax.set_ylim(max(allz) + pad, min(allz) - pad)  # -Z is forward: put forward at top
    ax.set_aspect("equal")
    ax.set_title(
        f"map_reverie  seed {seed}  ({len(blocks) - 1} blocks, dy {ymin:+.1f}..{ymax:+.1f})",
        color="#ffd9f4",
        fontsize=13,
    )
    ax.tick_params(colors="#7a6a80")
    for spine in ax.spines.values():
        spine.set_color("#3a2a40")
    ax.set_xlabel("X", color="#7a6a80")
    ax.set_ylabel("Z (forward \u2191)", color="#7a6a80")

    out_path = os.path.join(OUT, f"seed_{seed}.png")
    fig.savefig(out_path, dpi=110, facecolor=BG, bbox_inches="tight")
    plt.close(fig)
    print("wrote", out_path)
