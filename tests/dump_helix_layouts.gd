extends SceneTree

# Headless dumper: writes real generated block layouts for a set of seeds to a
# JSON file so the PR example gallery reflects the ACTUAL helix generator output.
#
# Run: godot --headless --script res://tests/dump_helix_layouts.gd

const SEEDS := [1, 42, 1337, 2024, 88888, 314159]
const COUNT := 90

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out: Dictionary = {}
	for seed in SEEDS:
		var gen := HelixGenerator.new(seed)
		gen.ensure(COUNT)
		var arr: Array = []
		# Include the spawn platform as index -1 for context (box footprint).
		arr.append({"x": 0.0, "y": 0.0, "z": HelixGenerator.START_Z, "r": 0.0, "sx": 10.0, "sz": 20.0, "shape": "box"})
		for i in range(COUNT):
			var b: Dictionary = gen.blocks[i]
			var c: Vector3 = b.center
			var rad: float = b.radius
			arr.append({"x": c.x, "y": c.y, "z": c.z, "r": rad, "sx": 2.0 * rad, "sz": 2.0 * rad, "shape": "cylinder"})
		out[str(seed)] = arr

	var f := FileAccess.open("res://tests/helix_layouts.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("wrote helix_layouts.json with %d seeds" % SEEDS.size())
	quit(0)
