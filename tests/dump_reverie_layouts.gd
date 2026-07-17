extends SceneTree

# Headless dumper: writes real generated block layouts for a set of seeds to a
# JSON file so the PR example gallery reflects the ACTUAL generator output.
#
# Run: godot --headless --script res://tests/dump_reverie_layouts.gd

const SEEDS := [1, 42, 1337, 2024, 88888, 314159]
const COUNT := 70

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out: Dictionary = {}
	for seed in SEEDS:
		var gen := EndlessGenerator.new(seed)
		gen.ensure(COUNT)
		var arr: Array = []
		# Include the spawn platform as index -1 for context.
		arr.append({"x": 0.0, "y": 0.0, "z": EndlessGenerator.START_Z, "sx": 10.0, "sz": 20.0})
		for i in range(COUNT):
			var b: Dictionary = gen.blocks[i]
			var c: Vector3 = b.center
			var sz: Vector2 = b.size
			arr.append({"x": c.x, "y": c.y, "z": c.z, "sx": sz.x, "sz": sz.y})
		out[str(seed)] = arr

	var f := FileAccess.open("res://tests/reverie_layouts.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("wrote reverie_layouts.json with %d seeds" % SEEDS.size())
	quit(0)
