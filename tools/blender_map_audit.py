"""Reusable pre-export QC audit for elimination-map Blender scenes.

Run this INSIDE Blender (Scripting console, or via the Blender MCP
`execute_blender_code`) against the live scene BEFORE exporting the .glb.
It complements `tools/map_qc.gd`, which runs post-import in Godot.

What it checks (all in Blender Z-up world space; assumes transforms applied
so local vertex coords == world coords):

  * floaters   - connected mesh islands whose base sits above the floor
                 (with a whitelist for caps/bands/tops that rest on a parent).
  * clips      - islands from one object that overlap islands of another
                 (e.g. a drum shoved inside a container, a deck through a wall).
  * ramps      - sample a walkable path and report the surface z gradient,
                 so you can see a ramp is monotonic and flush at top/bottom.
  * spawns     - for each intended spawn (in BLENDER coords), confirm there is
                 walkable floor below, head-room above, and a clear radius,
                 correctly treating "floor under a high catwalk" as walkable.

Axis reminder: Godot(x, y, z) = Blender(x, z, -y). A Team1 spawn at Godot
(sx, 1.1, sz) is Blender (sx, -sz, 0). Pass spawns in Blender XY here.

Usage example (bottom of file shows a __main__ block):

    import bpy, importlib
    import blender_map_audit as A         # if importable, else exec the file
    A.run(spawns=[(-4.5,-14),(0,-14),(4.5,-14),(-4.5,14),(0,14),(4.5,14)],
          collision_objects=['floor-col','walls-col','catwalk-col',
                             'cover-col','props-col','bridge-col'])
"""

import bpy
import bmesh
import math
from mathutils import Vector


def _islands(ob):
    """Return list of (xmin,xmax,ymin,ymax,zmin,zmax) for each connected island."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    comps = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        comp = []
        seen.add(v.index)
        while stack:
            w = stack.pop()
            comp.append(w)
            for e in w.link_edges:
                o = e.other_vert(w)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        xs = [p.co.x for p in comp]
        ys = [p.co.y for p in comp]
        zs = [p.co.z for p in comp]
        comps.append((min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    bm.free()
    return comps


def audit_floaters(name, floor_top=0.0, tol=0.15):
    """Islands whose base sits clearly above the floor. Caps/bands that rest on
    a taller island directly below them are excluded."""
    ob = bpy.data.objects.get(name)
    if ob is None:
        return []
    comps = _islands(ob)
    out = []
    for i, a in enumerate(comps):
        if a[4] <= floor_top + tol:
            continue
        # is there another island directly beneath this one? (a resting cap)
        rests = False
        for j, b in enumerate(comps):
            if i == j:
                continue
            overlap_xy = (min(a[1], b[1]) - max(a[0], b[0]) > 0 and
                          min(a[3], b[3]) - max(a[2], b[2]) > 0)
            if overlap_xy and b[4] <= a[4] + 0.2 and b[5] >= a[4] - 0.2:
                rests = True
                break
        if not rests:
            out.append([round(c, 2) for c in a])
    return out


def audit_clips(name_a, name_b, min_overlap=0.5):
    """Islands of A that interpenetrate islands of B by >min_overlap on all axes."""
    ia = _islands(bpy.data.objects[name_a])
    ib = _islands(bpy.data.objects[name_b])
    out = []
    for a in ia:
        for b in ib:
            ox = min(a[1], b[1]) - max(a[0], b[0])
            oy = min(a[3], b[3]) - max(a[2], b[2])
            oz = min(a[5], b[5]) - max(a[4], b[4])
            if ox > min_overlap and oy > min_overlap and oz > min_overlap:
                out.append({"a": [round(c, 1) for c in a],
                            "overlap": [round(ox, 1), round(oy, 1), round(oz, 1)]})
    return out


def _ray(x, y, z, dz):
    deps = bpy.context.evaluated_depsgraph_get()
    h = bpy.context.scene.ray_cast(deps, Vector((x, y, z)), Vector((0, 0, dz)))
    return (h[0], (h[1].z if h[0] else None), (h[4].name if h[0] else None))


def ramp_profile(points):
    """points: list of (x,y). Returns surface z + object hit at each, top-down."""
    out = []
    for (x, y) in points:
        ok, z, nm = _ray(x, y, 40, -1)
        out.append((round(x, 1), round(y, 1), round(z, 2) if ok else None, nm))
    return out


def _column(x, y, floor_names=("floor-col", "bridge-col"), deck_name="catwalk-col"):
    """Return (walkable_floor_z, blocked_reason, overhead_z)."""
    ok, z, nm = _ray(x, y, 40, -1)
    if not ok:
        return None, "hole", None
    if nm in floor_names and z < 0.4:
        return z, None, None
    if nm == deck_name and z > 2.4:  # a high catwalk; look for floor beneath it
        ok2, z2, nm2 = _ray(x, y, z - 0.6, -1)
        if ok2 and nm2 in floor_names and z2 < 0.4:
            return z2, None, round(z, 2)
        return None, "under-deck-blocked:%s" % nm2, None
    return None, "obstruction:%s@%.2f" % (nm, z), None


def audit_spawn(x, y, radius=1.5, headroom=2.3):
    """Return dict: clear / fully_open / issues for a spawn at Blender (x,y)."""
    issues = []
    overheads = 0
    pts = [(x, y, "c")]
    for a in range(0, 360, 45):
        pts.append((x + radius * math.cos(math.radians(a)),
                    y + radius * math.sin(math.radians(a)), "r%d" % a))
    for (px, py, tag) in pts:
        fz, reason, overhead = _column(px, py)
        if reason:
            issues.append((tag, reason))
            continue
        if overhead is not None:
            overheads += 1
            if overhead - fz < headroom:
                issues.append((tag, "low:%.2f" % (overhead - fz)))
        up, uz, unm = _ray(px, py, fz + 0.1, 1)
        if up and uz - fz < headroom:
            issues.append((tag, "ceil:%s@%.2f" % (unm, uz)))
    return {"clear": len(issues) == 0, "fully_open": overheads == 0,
            "issues": issues[:4]}


def run(spawns, collision_objects=None, visual_objects=None):
    """Run the full audit and print a report. Returns a dict of results."""
    if collision_objects is None:
        collision_objects = [o.name for o in bpy.context.scene.objects
                             if o.type == "MESH" and o.name.endswith("-col")]
    if visual_objects is None:
        visual_objects = [o.name for o in bpy.context.scene.objects
                          if o.type == "MESH" and not o.name.endswith("-col")]

    report = {"floaters": {}, "clips": [], "spawns": {}}
    # Floating COLLISION geometry is a bug; visual decor (hanging pipes, cables,
    # lamps) is allowed to be suspended, so only audit collision objects here.
    for nm in collision_objects:
        fl = audit_floaters(nm)
        if fl:
            report["floaters"][nm] = fl
    # Cross-object clips between every pair of collision objects.
    # NOTE: this is an axis-aligned-bounding-box test, so props sitting near an
    # angled wall segment (whose AABB is large) can show a false positive -
    # confirm with a render / distance check. The authoritative collision test
    # is tools/map_qc.gd (Godot physics) post-import.
    for i in range(len(collision_objects)):
        for j in range(i + 1, len(collision_objects)):
            c = audit_clips(collision_objects[i], collision_objects[j])
            if c:
                report["clips"].append({"pair": [collision_objects[i],
                                                 collision_objects[j]],
                                        "hits": c[:10]})
    for k, (sx, sy) in enumerate(spawns):
        report["spawns"]["spawn%d(%.1f,%.1f)" % (k, sx, sy)] = audit_spawn(sx, sy)

    ok = (not report["floaters"] and not report["clips"] and
          all(v["clear"] for v in report["spawns"].values()))
    print("=== blender_map_audit:", "PASS" if ok else "ISSUES FOUND", "===")
    for section in ("floaters", "clips"):
        if report[section]:
            print(section, ":", report[section])
    for name, r in report["spawns"].items():
        if not r["clear"]:
            print("spawn issue", name, r["issues"])
    report["ok"] = ok
    return report


if __name__ == "__main__":
    # Edit these for the map under construction, then run this file in Blender.
    run(spawns=[(-4.5, -14), (0, -14), (4.5, -14),
                (-4.5, 14), (0, 14), (4.5, 14)])
