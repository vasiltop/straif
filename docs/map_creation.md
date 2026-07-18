# Map Creation Guide (Elimination / CS-style maps)

This document captures the full pipeline and the design direction used to build
elimination maps for **straif** (Godot 4.6, units = **meters**). It exists so the
next map (or a redesign of an existing one) can be produced consistently without
re-deriving everything.

The reference implementation for these conventions is `snd_courtyard`
(`src/maps/elimination/snd_courtyard.tscn` + `src/maps/tiles/snd_courtyard.glb`).

---

## 1. Pipeline overview

Elimination maps are **authored as mesh geometry in Blender**, exported to a single
`.glb`, and that `.glb` is **instanced** inside the map's `.tscn`. This is the same
pipeline the bhop/speedrun maps use (they instance tiles like `flow.glb`).

```
Blender scene  ──export──►  src/maps/tiles/<map>.glb  ──instance──►  src/maps/elimination/<map>.tscn
```

Do **not** use CSG (`CSGCombiner3D` / `CSGBox3D`) for new/redesigned maps. The
original maps used CSG boxes; the real pipeline is Blender → `.glb`.

### Why Godot imports the `.glb` directly
`project.godot` sets `import/blender/enabled=false`. Godot therefore imports the
**pre-exported `.glb`** with its built-in glTF importer — it does **not** need
Blender installed at import time. You must commit/export the `.glb` yourself.

---

## 2. Collision — the `-col` name suffix (critical)

Collision is **baked from Blender object names**. The tile import preset has
`nodes/use_name_suffixes=true` (see any `src/maps/tiles/*.glb.import`), so:

> **Any Blender object whose name ends in `-col` becomes a Godot
> `StaticBody3D` + `CollisionShape3D` on import.**

Therefore **every solid object must be named with a `-col` suffix**, e.g.
`floor-col`, `wall_north-col`, `rock_12_4-col`, `crate_a-col`, `van_body-col`,
`ramp_a-col`. Objects without the suffix import as plain visual `MeshInstance3D`
(no collision) — use that only for purely decorative bits players can't touch.

Godot generates a **trimesh (concave) static collider** from the mesh by default
with this suffix, which is fine for static level geometry.

Other useful suffixes (from the importer): `-noimp` (skip), `-col` (static body),
`-convcol`, `-rigid`, `-vehicle`, `-occ`. We only use `-col`.

---

## 3. Scale & movement budget (meters)

Player capsule: **0.5 m wide × 2.1 m tall**. Source-style movement.

| Element | Value |
|---|---|
| Jump step-up | ~0.6 m (auto-step small ledges) |
| Stairs | rise ≤ 0.5 m per step for reliable ascent |
| Ramps | ≤ 45° |
| Doorways | ≥ **1.4 m** wide × **2.4 m** tall |
| Corridors | ≥ **2.0 m** wide (we use 4–6 m for combat lanes) |
| Chest-high cover | ~1.1 m tall (peek over) |
| Sightline-blocking walls | ≥ **2.6 m** (we use 7 m interior dividers) |
| Perimeter (unjumpable) | ≥ 6 m (we use 9–24 m natural cliffs) |
| Raised "high ground" | reachable via ramp/stairs, ~1.6–2.4 m above floor |

Players must not be able to escape or fall out — the arena must be **fully
bounded and sealed** (there are no killzones).

---

## 4. Design direction (art-directed requirements)

These are the accumulated requirements the map must satisfy. They came from live
review and apply to all elimination maps going forward:

1. **CS:GO-inspired competitive layout.** Two teams (T + CT) with **separate
   spawns**, two **bombsites (A + B)**, a **mid**, and connecting **lanes with real
   chokepoints**. Rotational (loop) flow, roughly fair/symmetric between teams.
2. **NOT a box.** Do **not** bound the arena with four straight walls. Bound it
   with **organic, curved, natural terrain** — jagged rock cliffs / mountains /
   gates — with an **irregular, non-rectangular silhouette**. Think a play space
   **carved out of a solid rock massif** (a "cave/canyon system").
3. **Not too open.** Dense cover, tight corridors, and thick walls between areas so
   there are **few long sightlines**. Prefer many **distinct rooms** over big open
   plazas. Deliberately place the few long angles (e.g. "A-long").
4. **Bigger + more, not larger rooms.** When scaling up, add **more rooms/routes**;
   keep individual room sizes modest.
5. **Vertical.** Raised site platforms, ramps, stairs, catwalks/bridges, 2-story
   buildings — give contested high ground.
6. **Moody lighting.** Dark-ish dusk mood, warm low sun, cool shadows/sky, fog.
7. **Realistic cover & props.** Crate stacks, barrels, sandbags, rubble/debris,
   a **van with actual tires**, etc.
8. **Textured, not flat.** CC0 **PBR** materials with **normal maps** (color +
   normal + roughness), embedded in the `.glb`.
9. **No floating geometry.** Everything must sit on the floor or on a real support —
   no pieces hovering above ramps/ground.

### Attribution
If external assets are used they must be **free for commercial use** (CC0 or
equivalent, e.g. ambientCG textures, Kenney kits). Record them in
`docs/ASSET_ATTRIBUTION.md` even when attribution is only "appreciated".

---

## 5. Recommended build method — grid-rasterized floorplan

The cleanest way to get a tight, CS-style, carved-cave layout (used by
`snd_courtyard`) is to **rasterize a 2D floorplan onto a grid** and carve the play
space out of a solid rock massif:

1. **Define the layout as rectangles** (rooms + linking corridors) in world meters,
   labeled (T, CT, A, B, mid, lanes, apps, etc.). Corridors must **overlap** the
   rooms they connect (that overlap becomes the doorway); keep ≥ 1 closed cell
   between areas you want walled off.
2. **Rasterize** onto a grid (cell = 2 m). A cell is `open` if any rectangle
   contains its center.
3. **Sanity-check cheaply as ASCII** before building geometry (open = space,
   `#` = wall). Iterate the rectangles here — it's free.
4. **Flood-fill from T spawn** to verify **every open cell is reachable** (no
   isolated rooms).
5. **Build floor** by merging open cells per row into slabs (`floor_*-col`, top at
   `Z=0`, ~1.2 m thick).
6. **Build the massif** by filling closed cells: **thin dividers** (≤ ~4 m) become
   built **stone walls** (~7 m tall); **thick regions** become **rock** (9 m+,
   taller toward the edges). Merge consecutive same-material/height cells per row
   to keep tri/object counts modest.
7. **Add a jagged rock belt** around the whole perimeter (varied heights 11–24 m,
   pushed in/out) so the outer silhouette is **not a rectangle**, plus a few taller
   background peaks for skyline.
8. **Detail pass:** site platforms + ramps/stairs/catwalks, cover (crates/barrels/
   sandbags/rubble), the van on tires, spawn positions.
9. **Texture pass** (see §7).

Keep tri counts modest — this is competitive greybox-plus geometry, not a beauty
render. Blender's Z-up maps to Godot's Y-up on glTF export (see §6).

### Coordinate convention (Blender, Z-up)
`X` = east(+)/west(−), `Y` = north(+)/south(−), `Z` = up.
Put **T spawn south (−Y)** and **CT spawn north (+Y)**; sites on opposite
sides (e.g. A east/NE, B west/SW).

---

## 6. Exporting from Blender

1. Build at **true meter scale**, Blender **Z up**.
2. **Apply all transforms** before/at export (`export_apply=True`) so local coords
   match world.
3. Confirm **every solid object name ends in `-col`**.
4. Export exactly one file to the tiles folder:

```python
bpy.ops.export_scene.gltf(
    filepath='<repo>/src/maps/tiles/<map>.glb',
    export_format='GLB',      # single self-contained binary (embeds textures)
    use_selection=False,
    export_apply=True,
)
```

> **glTF Y-up conversion:** Blender `Z` → Godot `Y`, and the horizontal axes are
> re-mapped — **one horizontal axis sign can flip**. Never assume spawn/world
> positions survive unchanged: after import, **read the actual Godot-space
> coordinates** of the imported nodes and place spawns to match (see §8).

---

## 7. Textures (CC0 PBR + normal maps)

- Use CC0 sets (e.g. ambientCG: Ground/Rock/Bricks/PavingStones/Wood/Metal), each
  providing `_Color`, `_NormalGL`, `_Roughness`.
- glTF does **not** export procedural Mapping-node scale — you must **bake UVs**.
  After applying transforms, generate **box/tri-planar-projection UVs** from world
  coords (~0.3–0.4 scale) so tiling survives export.
- Node graph per material: `Color → Base Color`; `Roughness` (Non-Color) →
  `Roughness`; `NormalGL` (Non-Color) → `Normal Map` → `Normal`.
- Set `GLB` export to embed images (`export_format='GLB'` embeds by default).
- The importer sets `meshes/ensure_tangents=true`, so normal maps work on import.

---

## 8. Godot wiring — the `.tscn`

Root is a `Node3D` (e.g. `Courtyard`). Rewrite the `.tscn` to:

1. **Add an `ext_resource`** PackedScene pointing at the glb and **instance it** as a
   child of the root, replacing the old geometry:

```gdscript
[ext_resource type="PackedScene" path="res://src/maps/tiles/<map>.glb" id="geo_1"]

[node name="<Map>Geo" parent="." instance=ExtResource("geo_1")]
```

2. **Delete the entire old `Geometry` CSG subtree** and its now-unused
   `StandardMaterial3D` / CSG sub-resources.
3. **Keep the spawn nodes exactly** — the game reads them by path:
   `elimination.gd` → `loaded_map.get_node("Spawns/Team%d" % team)` then iterates the
   child `Marker3D`s' `.global_position`. So preserve:

```
Spawns (Node3D)
├─ Team1 (Node3D)   ← south team (T)
│  ├─ Spawn1 (Marker3D)
│  ├─ Spawn2 (Marker3D)
│  └─ Spawn3 (Marker3D)
└─ Team2 (Node3D)   ← north team (CT)
   ├─ Spawn1 / Spawn2 / Spawn3 (Marker3D)
```

4. **Place the 6 spawn markers** on the correct team floor, **~0.1 m above the
   floor**, facing inward — using the **verified imported Godot coordinates** of the
   glb (account for the axis flip from §6), not the Blender coordinates.
5. **Keep `WorldEnvironment`**; retune `Sun` (`DirectionalLight3D`) + fog/sky to the
   map's mood (warm dusk for the courtyard).

---

## 9. Verification (headless, no commit)

Use the `godot` binary on `PATH`. If not present, a cached Godot 4.6 can be
extracted and run directly (e.g. `.../Godot.app/Contents/MacOS/Godot`).

```bash
# 1. (Re)import assets so the new .glb is picked up and a fresh .glb.import is written
godot --headless --editor --quit

# 2. Headless scene-load check: confirm the tscn loads with NO errors, the glb
#    instance has generated StaticBody3D/CollisionShape3D children (from -col names),
#    and all 6 Spawns/Team1|Team2/Spawn* nodes resolve.
```

Also sanity-check clearances against the 2.1 m player: doorway height/width, cover
heights, and that each spawn sits just above (not inside) the floor.

Confirm afterwards:
- `src/maps/tiles/<map>.glb` exists and a fresh `<map>.glb.import` references it.
- The `.tscn` instances the glb and the CSG subtree is gone.
- Collisions generate and all 6 spawns resolve on their correct sides.

---

## 10. Quick checklist

- [ ] Layout: T/CT spawns, A/B sites, mid, chokepoints; rotational; fair.
- [ ] Bounded by organic cliffs/gates — **irregular silhouette, not a box**, sealed.
- [ ] Tight, not too open; many rooms; deliberate long angles only.
- [ ] Vertical elements (ramps/stairs/catwalks/platforms) with valid step/slope.
- [ ] Every solid object named `*-col`.
- [ ] Transforms applied; exported one `.glb` to `src/maps/tiles/`.
- [ ] CC0 PBR + normal maps, UVs baked, embedded in glb; attribution recorded.
- [ ] No floating geometry.
- [ ] `.tscn` instances the glb; CSG removed; `Spawns/Team*/Spawn*` preserved.
- [ ] 6 spawns placed from verified imported coords, ~0.1 m above floor, facing in.
- [ ] Moody lighting (Sun + WorldEnvironment) tuned.
- [ ] Headless import + scene-load pass: no errors, collisions + 6 spawns resolve.
