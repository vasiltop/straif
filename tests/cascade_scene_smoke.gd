extends SceneTree

# Headless smoke test: the procedural map_cascade scene must instantiate cleanly,
# wire up the player, and stream generated beams around the spawn.
#
# Run: godot --headless --script res://tests/cascade_scene_smoke.gd

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://src/maps/speedrun/map_cascade.tscn")
	_check(packed != null, "map_cascade.tscn should load as a PackedScene")

	var map: Node = packed.instantiate()
	_check(map != null, "map_cascade.tscn should instantiate")
	root.add_child(map)

	await process_frame
	await process_frame

	_check(map.get("generator") != null, "runtime should build a ProceduralGenerator")
	_check(map.get("generator") is CascadeGenerator, "runtime should build the cascade pipeline")
	_check(map.get("run_seed") != 0, "runtime should pick a run seed")
	var nodes: Dictionary = map.get("block_nodes")
	_check(nodes.size() > 0, "runtime should stream in beam nodes around spawn")
	_check(is_instance_valid(map.get("player")), "runtime should have a Player node")

	map.free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
	printerr("FAIL: " + message)
