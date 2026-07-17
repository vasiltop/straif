#!/usr/bin/env python3
"""Render top-down example galleries from real helix generator output.

Reads tests/helix_layouts.json (produced by tests/dump_helix_layouts.gd) and
writes one top-down PNG per seed to images/procedural_examples/map_helix/. Each
cylinder pad is drawn as a circle at its XZ footprint, colored by height (Y),
with the spiral path traced through the pad centers. The spawn platform is drawn
as a grey rectangle. A teal / cyan "sky temple" palette matches the map.
"""
import json
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle
from matplotlib.collections import PatchCollection

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tests", "helix_layouts.json")
OUT = os.path.join(ROOT, "images", "procedural_examples", "map_helix")

os.makedirs(OUT, exist_ok=True)

with open(DATA) as fh:
    layouts = json.load(fh)

# Teal / cyan sky-temple palette.
BG = "#071417"
PATH = "#5ff4e8"
SPAWN = "#3a5a5f"

for seed in sorted(layouts.keys(), key=lambda s: int(s)):
    blocks = layouts[seed]
    ys = [b["y"] for b in blocks[1:]]
    ymin, ymax = min(ys), max(ys)
    yspan = (ymax - ymin) or 1.0

    fig, ax = plt.subplots(figsize=(8, 8))
    fig.patch.set_facecolor(BG)
    ax.set_facecolor(BG)

    patches = []
    colors = []
    for idx, b in enumerate(blocks):
        if idx == 0:
            sx, sz = b["sx"], b["sz"]
            patches.append(Rectangle((b["x"] - sx / 2.0, b["z"] - sz / 2.0), sx, sz))
            colors.append(SPAWN)
        else:
            patches.append(Circle((b["x"], b["z"]), b["r"]))
            t = (b["y"] - ymin) / yspan
            # cool teal -> cyan ramp by height
            colors.append(plt.cm.winter(0.15 + 0.7 * t))

    pc = PatchCollection(patches, facecolor=colors, edgecolor="#ffffff22", linewidths=0.4)
    ax.add_collection(pc)

    px = [b["x"] for b in blocks[1:]]
    pz = [b["z"] for b in blocks[1:]]
    ax.plot(px, pz, color=PATH, linewidth=1.1, alpha=0.85, zorder=5)
    ax.scatter(px[:1], pz[:1], color="#ffffff", s=30, zorder=6, label="start")

    allx = [b["x"] for b in blocks]
    allz = [b["z"] for b in blocks]
    pad = 4.0
    ax.set_xlim(min(allx) - pad, max(allx) + pad)
    ax.set_ylim(max(allz) + pad, min(allz) - pad)  # -Z is forward: put forward at top
    ax.set_aspect("equal")
    ax.set_title(
        f"map_helix  seed {seed}  ({len(blocks) - 1} blocks, climb {ymin:+.1f}..{ymax:+.1f})",
        color="#c8fff7",
        fontsize=13,
    )
    ax.tick_params(colors="#4f7a7f")
    for spine in ax.spines.values():
        spine.set_color("#1e3a3f")
    ax.set_xlabel("X", color="#4f7a7f")
    ax.set_ylabel("Z (forward \u2191)", color="#4f7a7f")

    out_path = os.path.join(OUT, f"seed_{seed}.png")
    fig.savefig(out_path, dpi=110, facecolor=BG, bbox_inches="tight")
    plt.close(fig)
    print("wrote", out_path)
