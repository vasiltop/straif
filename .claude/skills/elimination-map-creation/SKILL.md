---
name: elimination-map-creation
description: >-
  Use when creating, redesigning, or editing a straif elimination / CS-style map
  (the maps in src/maps/elimination/*.tscn). Covers the full pipeline: authoring
  geometry in Blender, exporting a single .glb tile, baking collision via -col
  name suffixes, wiring the .tscn (instance + spawns), CC0 / pixel textures, the
  glTF Z-up→Y-up axis mapping, object merging for efficiency, and headless
  verification. Godot 4.6, units = meters.
---

# Elimination map creation (straif)

Build brand-new elimination maps as **mesh geometry authored in Blender**,
exported to one `.glb`, and **instanced** inside the map's `.tscn`. Do **not**
use CSG (`CSGCombiner3D`/`CSGBox3D`) for new/redesigned maps.

The reference implementation is **`snd_courtyard`**
(`src/maps/elimination/snd_courtyard.tscn` + `src/maps/tiles/snd_courtyard.glb`).
The full, detailed guide lives in **`docs/map_creation.md`** — read it for the
grid-rasterized floorplan method, the design direction, and the checklist. This
skill is the fast operational summary plus the hard-won gotchas.

## Pipeline

```
Blender scene ──export──► src/maps/tiles/<map>.glb ──instance──► src/maps/elimination/<map>.tscn
```

`project.godot` sets `import/blender/enabled=false`, so Godot imports the
**pre-exported `.glb`** with its glTF importer — Blender is **not** needed at
import time. You must export and commit the `.glb` yourself.

## Rule 1 — collision via the `-col` name suffix (critical)

The tile import preset has `nodes/use_name_suffixes=true`, so:

> **Any Blender object whose name ends in `-col` becomes a Godot
> `StaticBody3D` + `CollisionShape3D` (trimesh) on import.**

Name **every solid object** with a `-col` suffix (`floor-col`, `walls-col`,
`crate_a-col`, …). Objects without the suffix import as plain visual
`MeshInstance3D` with **no collision** — use that for purely decorative bits
players can't touch (e.g. window boards, lamps flush on a wall).

## Rule 2 — scale & movement budget (meters)

Player capsule **0.5 w × 2.1 h**, Source-style movement.

| Element | Value |
|---|---|
| Jump step-up | ~0.6 m |
| Stairs | rise ≤ 0.5 m/step |
| Ramps | ≤ 45° |
| Doorways | ≥ 1.4 w × 2.4 h |
| Corridors | ≥ 2.0 w |
| Chest-high cover | ~1.1 m |
| Sightline walls | ≥ 2.6 m |
| Perimeter (unjumpable) | ≥ 6 m |

Arena must be **fully bounded and sealed** (no killzones) — players can't fall
or escape. Verify ≥ ~2.3 m overhead clearance on all walkable paths.

## Rule 3 — build method (grid-rasterized floorplan)

Author a tight, carved-cave CS layout by rasterizing a 2D floorplan on a grid,
then extruding: floor slabs at top `Z=0`; thin closed cells → built stone walls
(~7 m); thick regions → rock massif (9 m+); a jagged perimeter belt (varied
11–24 m, irregular silhouette — **not a rectangle**). Flood-fill from T spawn to
prove every open cell is reachable. Detail pass: site platforms, ramps/stairs/
catwalks, cover (crates/barrels/sandbags/rubble), a van on tires. See
`docs/map_creation.md` §5 for the step-by-step.

Requirements: T/CT spawns, A/B sites, mid, real chokepoints; rotational + fair;
dense cover (few long sightlines); vertical high ground; moody dusk lighting.

## Rule 4 — glTF axis mapping (verified)

Blender is **Z-up**; glTF export converts to Y-up. Measured on `snd_courtyard`:

```
Godot(x, y, z) = Blender(x, z, -y)
```

i.e. **Godot Y = Blender Z (up)**, **Godot Z = −Blender Y**, Godot X = Blender X.
So **T spawn south (Blender −Y) lands at Godot +Z**; CT north (Blender +Y) at
Godot −Z. One horizontal sign flips — **never assume**; read the actual imported
coordinates (raycast probe) before placing spawns.

## Rule 5 — export from Blender

```python
bpy.ops.export_scene.gltf(
    filepath='<repo>/src/maps/tiles/<map>.glb',
    export_format='GLB',       # single binary, embeds textures
    use_selection=False,
    export_apply=True,         # apply transforms so local == world
    export_yup=True,
)
```

Confirm **every solid object name ends in `-col`** before exporting.

## Rule 6 — efficiency: merge before export

A cell-per-object greybox can explode into thousands of objects → thousands of
`StaticBody3D`. **Merge objects by role/material** into a handful of `-col`
meshes with `bpy.ops.object.join()` (use `bpy.context.temp_override(...)`).
`snd_courtyard` merges to ~10 objects: `floor-col`, `walls-col`, `cliffs-col`,
`cover-col`, `catwalk-col`, `van-col`, `sites-col`, `gates-col`, plus
collision-free visual meshes `windows` and `lamps`. Joins preserve per-vertex
UVs and multi-material assignment; each merged `-col` mesh is one trimesh body
(ideal for static geometry). This cut the tile from ~1500 bodies → 8 and the
GLB from 28 MB → ~2.5 MB.

Decorative props that sit flush on a wall (window boards, lamps) don't need
collision — drop their `-col` suffix so they import as visual-only.

## Rule 7 — textures

Two supported looks; both embed images in the GLB and bake UVs (glTF does **not**
export procedural Mapping-node scale — after applying transforms, generate
box/tri-planar UVs from world coords, ~0.3–0.4 scale).

- **PBR:** CC0 sets (ambientCG Ground/Rock/Bricks/PavingStones/Wood/Metal), each
  `Color → Base Color`, `Roughness` (Non-Color) → `Roughness`, `NormalGL`
  (Non-Color) → `Normal Map → Normal`. Importer sets `ensure_tangents=true`.
- **Pixel-art (snd_courtyard follow-up):** downscale source images to small
  powers (128², down to ~48² for chunky surfaces), **drop normal maps** for a
  flat look + smaller file, and set **nearest texture filtering** via an
  `EditorScenePostImport` script wired into the `.glb.import`:

  ```gdscript
  # src/maps/tiles/<map>_post_import.gd
  @tool
  extends EditorScenePostImport
  func _post_import(scene: Node) -> Object:
      _apply(scene); return scene
  func _apply(node: Node) -> void:
      if node is MeshInstance3D and (node as MeshInstance3D).mesh:
          var m := (node as MeshInstance3D).mesh
          for i in m.get_surface_count():
              var mat := m.surface_get_material(i)
              if mat is BaseMaterial3D:
                  (mat as BaseMaterial3D).texture_filter = \
                      BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
      for c in node.get_children(): _apply(c)
  ```

  Wire it: in `<map>.glb.import` set
  `import_script/path="res://src/maps/tiles/<map>_post_import.gd"`.
  Godot **re-extracts embedded textures on reimport**, so any downscaling must be
  baked into the GLB (scale + pack images in Blender, then export) — resizing the
  extracted files on disk gets overwritten.

Record any external assets (CC0 / commercial-OK) in `docs/ASSET_ATTRIBUTION.md`.

## Rule 8 — wire the `.tscn`

Root is a `Node3D`. The scene must:

1. Add an `ext_resource` PackedScene for the glb and **instance it** as a child
   of the root (replacing any old geometry). Delete any old `Geometry` CSG
   subtree + its unused sub-resources.
2. **Keep the spawn nodes exactly** — `elimination.gd` reads
   `Spawns/Team%d` then iterates child `Marker3D` `.global_position`:
   ```
   Spawns/Team1/Spawn1..3   ← south team (T),  faces +Z→−Z (identity basis)
   Spawns/Team2/Spawn1..3   ← north team (CT), faces −Z→+Z (180° Y basis)
   ```
3. Place the 6 markers on the correct team floor, **~0.1 m above** it (marker
   `y = floor_y + 1.1` places feet ~0.1 m up), facing inward — using the
   **verified imported Godot coordinates** (Rule 4), not Blender coords.
4. Keep `WorldEnvironment`; tune `Sun` (`DirectionalLight3D`) + fog/sky to mood.

## Rule 9 — verify headless (no commit)

Use the `godot` binary on `PATH` (or a cached Godot 4.6 at
`.../Godot.app/Contents/MacOS/Godot`).

```bash
# 1. Reimport so the new .glb is picked up + fresh .glb.import written
godot --headless --path . --editor --quit

# 2. Run the committed, reusable QC harness (see Rule 12):
godot --headless --path . -s tools/map_qc.gd -- --map=<map>
```

`tools/map_qc.gd` confirms: the `.tscn` loads with **no errors**; the glb
instance generated **StaticBody3D + CollisionShape3D** children (one per `-col`
group); all **6 `Spawns/Team{1,2}/Spawn{1..3}`** resolve; and each spawn passes
a physics clearance test (not embedded, floor below, head-room, escape room).
Exit code 0 = pass. Then sanity-check clearances vs the 2.1 m player.

Headless gotchas: give types in GDScript (`var hit: Dictionary`,
`var space: PhysicsDirectSpaceState3D`). Run SceneTree scripts via `-s` (NOT a
positional arg — that hangs). Add the map instance to `get_root()` and wait a
few `physics_frame`s before querying the space, then filter `intersect_shape`
hits to `is_ancestor_of(collider)` so autoloaded maps in the same physics space
don't pollute results. `get_global_transform` errors in `_init` (not in tree).

## Rule 10 — dressing with props (CS-style clutter) & organic collision

Open floors read as empty. Populate them with dense, believable clutter
(market stalls, oil drums, gas cylinders, crates, baskets, fruit displays,
tables/chairs, planters, traffic cones, pallets/sacks, tarps, pipes, ladders,
carpets/rugs, signs) — mirroring Dust2/Mirage/Cache prop vocabulary. Keep it
**greybox-plus**: simple primitives, chunky silhouettes, no beauty detail.

**Two objects per prop pass — split visual from collision:**

- Merge all **decorative** prop meshes into one collision-free visual object
  (e.g. `bazaar`, `rubble`) — no `-col` suffix, so they cost nothing physically.
- Merge the **blocking** proxies into one `-col` object (e.g. `bazaar-col`).
  Use **simplified box/convex proxies**, not the detailed visual mesh, for
  collision. This keeps the trimesh cheap and avoids snag geometry.

**Organic props (rocks, rubble, boulders) → convex-hull collision.**
A detailed concave rock imported as its own trimesh `-col` creates **inward
pockets that wedge the 0.5×2.1 capsule** (player gets stuck on jump-down) and,
because the wedge leaves residual velocity, retriggers the footstep loop
(`player.gd` fires footsteps while `velocity>0 && grounded()`). Fix: keep the
detailed rock as **visual-only** (`rubble`) and add a **convex hull** proxy to
the `-col` object — a convex trimesh has no inward pocket, so the capsule slides
off cleanly. Per cluster:

```python
res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
# delete ONLY interior verts — don't concat geom_interior+unused+holes (dupes → error)
interior = [e for e in res['geom_interior'] if isinstance(e, bmesh.types.BMVert)]
bmesh.ops.delete(bm, geom=interior, context='VERTS')
```

Cluster loose rocks by centroid distance (<~2.5 m) and hull each cluster
separately so hulls hug the shapes (one giant hull would swallow walkways).

**Place props with a downward raycast so nothing floats or clips:**

```python
deps = bpy.context.evaluated_depsgraph_get()
hit = bpy.context.scene.ray_cast(deps, Vector((x, y, 60)), Vector((0,0,-1)))
# open floor only if it hit the floor near Z=0 (not another prop/wall):
ok = hit[0] and hit[1].z < 0.35 and hit[4].name.startswith('floor')
```

Seat each prop's base on `hit[1].z`. Enforce a min-distance list between anchors
so clusters don't interpenetrate, and keep clusters ~1 m off walls (the raycast
validates only the anchor point — a wide cluster can still clip a nearby wall).
**Never fully block a lane/chokepoint** — after placing, re-check a top-down
render that every route is still passable.

**New pixel textures for props** (reuse existing materials first): create tiny
images in Blender and pack them —

```python
img = bpy.data.images.new('fruit_mix', 16, 16)
img.pixels = flat_rgba_list          # len == w*h*4
img.pack()
tex = nodes.new('ShaderNodeTexImage'); tex.image = img
tex.interpolation = 'Closest'        # nearest look; post-import script also forces it
```

Keep them 16–32 px. Godot re-extracts embedded textures on reimport and the
post-import script (Rule 7) forces nearest filtering, so the pixel look is
automatic — no on-disk resizing.

**Editing a merged group later:** `mesh.separate(type='LOOSE')` → edit parts →
re-`join` via `bpy.context.temp_override(active_object=t,
selected_editable_objects=list, selected_objects=list)`, then set `.name` +
`.data.name`. Gotcha: if another object still holds the target name at rename
time, Blender appends `.NNN` — rename again once the collider is consumed.

## Rule 12 — automated QC (reusable, committed)

Two committed scripts catch the bugs that keep recurring (spawns embedded in
geometry, players stuck under low catwalks, floating collision, ramps that need
a jump at the top, props clipping walls). **Run both when iterating on a map.**

**`tools/blender_map_audit.py`** — pre-export, runs in Blender against the live
scene (Scripting console or the MCP `execute_blender_code`; `exec()` the file
then call `run(spawns=[...blender XY...])`). Reports:
- *floaters* — connected islands of a `-col` object whose base sits above the
  floor with nothing beneath (a real bug). Visual decor may hang, so it only
  audits collision objects; caps/bands resting on a parent are excluded.
- *clips* — islands of one object interpenetrating another (drum inside a
  container, deck through a wall). **AABB-based**, so props near an *angled*
  wall segment (large AABB) can false-positive — confirm with a render or a
  point-to-line distance before "fixing".
- *ramps* — `ramp_profile([(x,y),...])` prints the top-down surface z along a
  path so you can see a ramp is monotonic and flush at both ends (no step/jump).
- *spawns* — for each spawn (in **Blender** XY), walkable floor below,
  head-room, and a clear radius, correctly treating "floor under a high
  catwalk" as walkable (cast down again from just below the deck).

**`tools/map_qc.gd`** — post-import, the authoritative check (real collision
shapes, no AABB false positives). `godot --headless --path . -s tools/map_qc.gd
-- --map=<map>`. Fails (exit 1) if collision is missing, a spawn is missing,
or a spawn capsule is embedded / floating / has a low ceiling / is boxed in
(needs ≥5 of 8 escape directions). Spawns are allowed to sit *near* cover — the
requirement is "not inside anything, with room to move out", not empty space on
all sides.

Workflow: build → `blender_map_audit.run(...)` → fix floaters/clips/ramps →
export → reimport → `map_qc.gd`. Both green before you show or commit.

## Checklist

- [ ] Layout: T/CT spawns, A/B sites, mid, chokepoints; rotational; fair.
- [ ] Bounded by organic cliffs/gates — irregular silhouette, sealed.
- [ ] Tight, not too open; many rooms; deliberate long angles only.
- [ ] Vertical elements with valid step/slope.
- [ ] Every solid object named `*-col`; props flush on walls left visual-only.
- [ ] Objects merged by role → few `-col` bodies; transforms applied.
- [ ] Exactly one `.glb` in `src/maps/tiles/`; textures embedded, UVs baked.
- [ ] (Pixel look) small textures, normals dropped, nearest-filter post-import
      script wired in `.glb.import`.
- [ ] No floating geometry.
- [ ] Props dress open floors (visual object + separate `-col` proxy); organic
      rocks are visual-only with convex-hull collision; no lane blocked.
- [ ] `.tscn` instances the glb; CSG removed; `Spawns/Team*/Spawn*` preserved.
- [ ] 6 spawns from verified imported coords, ~0.1 m above floor, facing in.
- [ ] Spawns pass `tools/map_qc.gd` (not embedded, floor below, head-room,
      escape room) and `blender_map_audit` spawn check is clear.
- [ ] Ramps monotonic + flush at top/bottom (no jump/step); posts reach the
      surface below; no props clipping walls/each other (audit clean or a
      confirmed AABB false-positive).
- [ ] Moody lighting tuned.
- [ ] Headless import + `tools/map_qc.gd` pass (exit 0): no errors, collisions
      + 6 spawns resolve and clear.
