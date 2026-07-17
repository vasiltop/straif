#!/usr/bin/env python3
"""Render example-map galleries for map_cascade from real generator output.

Reads tests/cascade_layouts.json (produced by tests/dump_cascade_layouts.gd) and
writes one PNG per seed to images/procedural_examples/map_cascade/. Each seed gets
two panels:

  * Top-down: every narrow beam drawn as a rotated rectangle at its XZ footprint,
    oriented along its yaw (the path heading), colored by height (Y), with the
    path traced through beam centers. The spawn platform is drawn in grey.
  * Side elevation: cumulative horizontal distance vs. height, showing the net
    downward, switchbacking descent this map is built around.
"""
import json
import math
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Rectangle
from matplotlib.collections import PatchCollection

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tests", "cascade_layouts.json")
OUT = os.path.join(ROOT, "images", "procedural_examples", "map_cascade")

os.makedirs(OUT, exist_ok=True)

# Dark canyon / amber palette.
BG = "#140d08"
PATH = "#ffb347"
SPAWN = "#5a4636"
GRID = "#3a2a1a"
TXT = "#ffd9a8"
MUTE = "#8a6a4a"


def beam_corners(b):
    """Four XZ corners of a beam, oriented along its yaw heading."""
    x, z = b["x"], b["z"]
    sx, sz = b["sx"], b["sz"]
    yaw = b.get("yaw", 0.0)
    # Long axis follows the path heading (cos yaw, sin yaw) in (x, z); narrow
    # axis is perpendicular.
    lx, lz = math.cos(yaw), math.sin(yaw)
    nx, nz = -math.sin(yaw), math.cos(yaw)
    hx, hz = sx / 2.0, sz / 2.0
    return [
        (x + lx * hx + nx * hz, z + lz * hx + nz * hz),
        (x + lx * hx - nx * hz, z + lz * hx - nz * hz),
        (x - lx * hx - nx * hz, z - lz * hx - nz * hz),
        (x - lx * hx + nx * hz, z - lz * hx + nz * hz),
    ]


with open(DATA) as fh:
    layouts = json.load(fh)

for seed in sorted(layouts.keys(), key=lambda s: int(s)):
    blocks = layouts[seed]
    beams = blocks[1:]
    ys = [b["y"] for b in beams]
    ymin, ymax = min(ys), max(ys)
    yspan = (ymax - ymin) or 1.0

    fig, (ax, axe) = plt.subplots(
        1, 2, figsize=(15, 8), gridspec_kw={"width_ratios": [1.35, 1.0]}
    )
    fig.patch.set_facecolor(BG)

    # --- Top-down --------------------------------------------------------
    ax.set_facecolor(BG)
    patches = []
    colors = []
    # Spawn platform (axis-aligned).
    sp = blocks[0]
    patches.append(
        Rectangle((sp["x"] - sp["sx"] / 2.0, sp["z"] - sp["sz"] / 2.0), sp["sx"], sp["sz"])
    )
    colors.append(SPAWN)
    for b in beams:
        patches.append(Polygon(beam_corners(b), closed=True))
        t = (b["y"] - ymin) / yspan
        # Amber (high) -> deep red/brown (low).
        colors.append(plt.cm.inferno(0.30 + 0.55 * t))

    pc = PatchCollection(patches, facecolor=colors, edgecolor="#00000055", linewidths=0.4)
    ax.add_collection(pc)

    px = [b["x"] for b in beams]
    pz = [b["z"] for b in beams]
    ax.plot(px, pz, color=PATH, linewidth=1.1, alpha=0.85, zorder=5)
    ax.scatter(px[:1], pz[:1], color="#ffffff", s=32, zorder=6)

    allx = [b["x"] for b in blocks]
    allz = [b["z"] for b in blocks]
    pad = 6.0
    ax.set_xlim(min(allx) - pad, max(allx) + pad)
    ax.set_ylim(max(allz) + pad, min(allz) - pad)  # -Z is forward: forward at top
    ax.set_aspect("equal")
    ax.set_title(
        "map_cascade  seed %s  (%d beams)" % (seed, len(beams)),
        color=TXT,
        fontsize=13,
    )
    ax.set_xlabel("X", color=MUTE)
    ax.set_ylabel("Z (forward \u2191)", color=MUTE)

    # --- Side elevation --------------------------------------------------
    axe.set_facecolor(BG)
    dist = [0.0]
    for i in range(1, len(beams)):
        dx = beams[i]["x"] - beams[i - 1]["x"]
        dz = beams[i]["z"] - beams[i - 1]["z"]
        dist.append(dist[-1] + math.hypot(dx, dz))
    axe.plot(dist, ys, color=PATH, linewidth=1.4, alpha=0.9, zorder=4)
    axe.scatter(dist, ys, c=range(len(ys)), cmap="inferno", s=10, zorder=5)
    axe.set_title(
        "descent profile  (dy %+.1f .. %+.1f)" % (ymin, ymax), color=TXT, fontsize=13
    )
    axe.set_xlabel("distance along path", color=MUTE)
    axe.set_ylabel("height (Y)", color=MUTE)
    axe.grid(True, color=GRID, linewidth=0.5, alpha=0.6)

    for a in (ax, axe):
        a.tick_params(colors=MUTE)
        for spine in a.spines.values():
            spine.set_color(GRID)

    out_path = os.path.join(OUT, "seed_%s.png" % seed)
    fig.savefig(out_path, dpi=110, facecolor=BG, bbox_inches="tight")
    plt.close(fig)
    print("wrote", out_path)
