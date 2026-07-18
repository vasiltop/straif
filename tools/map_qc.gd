extends SceneTree

## Reusable headless QC for elimination maps.
##
## Loads src/maps/elimination/<map>.tscn, then checks:
##   1. the scene loads with no error;
##   2. the glb instance produced StaticBody3D + CollisionShape3D children
##      (one body per `-col` object) — i.e. collision baked correctly;
##   3. all 6 `Spawns/Team{1,2}/Spawn{1..3}` markers resolve;
##   4. each spawn is NOT embedded in geometry (a player-sized capsule fits),
##      sits above a floor within reach, has head-room, and has a clear
##      horizontal radius (no solid within RADIUS at torso height).
##
## Usage:
##   godot --headless --path . -s tools/map_qc.gd -- --map=snd_foundry
## Exit code 0 = all pass, 1 = any failure (CI-friendly).
##
## Player capsule: 0.5 wide x 2.1 tall (radius 0.25). We test a slightly
## fatter capsule (r 0.3) for margin. RADIUS is the required clear space
## around each spawn.

const CAP_RADIUS := 0.28
const CAP_HEIGHT := 2.1
const RADIUS := 1.0
const MIN_CLEAR_DIRS := 5  # of 8; a spawn may sit near cover but must have escape room
const HEADROOM := 2.3

var _map: Node3D
var _phys_ticks := 0
var _map_name := "snd_foundry"


func _init() -> void:
	_map_name = _arg("--map", "snd_foundry")
	var path := "res://src/maps/elimination/%s.tscn" % _map_name
	var ps: PackedScene = load(path)
	if ps == null:
		printerr("QC FAIL: could not load ", path)
		quit(1)
		return
	var inst := ps.instantiate()
	if not (inst is Node3D):
		printerr("QC FAIL: root is not Node3D")
		quit(1)
		return
	_map = inst
	get_root().add_child(_map)
	physics_frame.connect(_on_physics)


func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _on_physics() -> void:
	# let bodies register in the physics space before querying
	_phys_ticks += 1
	if _phys_ticks < 3:
		return
	physics_frame.disconnect(_on_physics)
	quit(0 if _run_checks() else 1)


func _run_checks() -> bool:
	var ok := true
	print("=== map_qc: ", _map_name, " ===")

	# 1+2. collision bodies / shapes
	var bodies := 0
	var shapes := 0
	var stack: Array = [_map]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is StaticBody3D:
			bodies += 1
		if n is CollisionShape3D:
			shapes += 1
		for c in n.get_children():
			stack.append(c)
	print("collision: bodies=", bodies, " shapes=", shapes)
	if bodies < 1 or shapes < 1:
		printerr("QC FAIL: no collision generated (check -col name suffixes)")
		ok = false

	# 3+4. spawns
	var space := _map.get_world_3d().direct_space_state
	for team in ["Team1", "Team2"]:
		for i in [1, 2, 3]:
			var p := "Spawns/%s/Spawn%d" % [team, i]
			var m := _map.get_node_or_null(p) as Node3D
			if m == null:
				printerr("QC FAIL: missing ", p)
				ok = false
				continue
			var pos := m.global_position
			var res := _check_spawn(space, pos)
			if res.is_empty():
				print("spawn OK  ", p, " ", pos)
			else:
				printerr("QC FAIL: ", p, " ", pos, " -> ", res)
				ok = false

	print("=== map_qc PASS ===" if ok else "=== map_qc FAIL ===")
	return ok


## Returns [] if the spawn is clear, else a list of problem strings.
func _check_spawn(space: PhysicsDirectSpaceState3D, pos: Vector3) -> Array:
	var problems: Array = []

	# (a) capsule at the spawn must not intersect map geometry
	if _capsule_hits(space, pos):
		problems.append("embedded (capsule intersects geometry)")

	# (b) floor within reach below, with head-room above
	var down := PhysicsRayQueryParameters3D.create(
		pos + Vector3(0, 0.2, 0), pos + Vector3(0, -4.0, 0))
	var hit := space.intersect_ray(down)
	if hit.is_empty():
		problems.append("no floor within 4m below")
	else:
		var floor_y: float = hit.position.y
		if pos.y - floor_y > 2.0:
			problems.append("floating %.2fm above floor" % (pos.y - floor_y))
		var up := PhysicsRayQueryParameters3D.create(
			Vector3(pos.x, floor_y + 0.15, pos.z),
			Vector3(pos.x, floor_y + 6.0, pos.z))
		var ch := space.intersect_ray(up)
		if not ch.is_empty() and ch.position.y - floor_y < HEADROOM:
			problems.append("low ceiling (%.2fm)" % (ch.position.y - floor_y))

	# (c) enough clear horizontal room to move out (spawns may sit near cover,
	# but must not be boxed in on all sides)
	var clear_dirs := 0
	for a in range(0, 360, 45):
		var off := Vector3(RADIUS * cos(deg_to_rad(a)), 0, RADIUS * sin(deg_to_rad(a)))
		if not _capsule_hits(space, pos + off, 0.2):
			clear_dirs += 1
	if clear_dirs < MIN_CLEAR_DIRS:
		problems.append("too enclosed (%d/8 dirs clear at r=%.1f)" % [clear_dirs, RADIUS])

	return problems


func _capsule_hits(space: PhysicsDirectSpaceState3D, center: Vector3, r := CAP_RADIUS) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = CAP_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), center)
	q.collision_mask = 0xFFFFFFFF
	var hits := space.intersect_shape(q, 16)
	for h in hits:
		var col = h.get("collider")
		if col != null and _map.is_ancestor_of(col):
			return true
	return false
