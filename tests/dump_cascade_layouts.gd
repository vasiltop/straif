extends SceneTree

# Headless dumper: writes real generated beam layouts for a set of seeds to a
# JSON file so the PR example gallery reflects the ACTUAL generator output.
#
# Run: godot --headless --script res://tests/dump_cascade_layouts.gd

const SEEDS := [1, 42, 1337, 2024, 88888, 314159]
const COUNT := 90

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out: Dictionary = {}
	for seed in SEEDS:
		var gen := CascadeGenerator.new(seed)
		gen.ensure(COUNT)
		var arr: Array = []
		# Include the spawn platform as index -1 for context (10 wide, 20 deep).
		arr.append({"x": 0.0, "y": 0.0, "z": CascadeGenerator.START_Z, "sx": 10.0, "sz": 20.0, "yaw": 0.0})
		for i in range(COUNT):
			var b: Dictionary = gen.blocks[i]
			var c: Vector3 = b.center
			var sz: Vector2 = b.size
			arr.append({"x": c.x, "y": c.y, "z": c.z, "sx": sz.x, "sz": sz.y, "yaw": b.yaw})
		out[str(seed)] = arr

	var f := FileAccess.open("res://tests/cascade_layouts.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("wrote cascade_layouts.json with %d seeds" % SEEDS.size())
	quit(0)
