extends SceneTree

# Headless determinism + solvability self-test for the procedural endless bhop
# map (map_reverie). Because block placement uses the model speed (not the live
# player velocity), the whole layout is a pure function of the seed. This test:
#   (a) generates hundreds of blocks for several seeds and asserts EVERY
#       consecutive gap is clearable at the model speed with margin, and
#   (b) asserts the same seed reproduces identical block positions, while
#       different seeds diverge.
#
# Run: godot --headless --script res://tests/procedural_reverie_selftest.gd

const SEEDS := [1, 42, 1337, 999999, 2024, 7]
const BLOCK_COUNT := 400
const SAFETY := 0.95

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for seed in SEEDS:
		_check_solvable(seed)

	_check_determinism()
	_check_variety()

	quit(1 if failed else 0)

func _check_solvable(seed: int) -> void:
	var gen := EndlessGenerator.new(seed)
	gen.ensure(BLOCK_COUNT)

	_check(gen.blocks.size() == BLOCK_COUNT, "seed %d should generate %d blocks" % [seed, BLOCK_COUNT])

	var prev := Vector3(0.0, 0.0, EndlessGenerator.START_Z)
	for i in range(BLOCK_COUNT):
		var spec: Dictionary = gen.blocks[i]
		var cur: Vector3 = spec.center
		var dy := cur.y - prev.y

		var dx := cur.x - prev.x
		var dz := cur.z - prev.z
		var dist := sqrt(dx * dx + dz * dz)

		var s := EndlessGenerator.model_speed(i)
		var reach := EndlessGenerator.max_reach(s, dy)

		_check(
			dist <= reach * SAFETY,
			"seed %d block %d gap %.3f exceeds clearable reach %.3f (dy=%.3f, s=%.2f)" % [seed, i, dist, reach * SAFETY, dy, s]
		)
		_check(
			dy <= EndlessGenerator.MAX_UP_STEP + 0.001,
			"seed %d block %d up-step %.3f exceeds max %.3f" % [seed, i, dy, EndlessGenerator.MAX_UP_STEP]
		)
		_check(
			dist > 0.1,
			"seed %d block %d should advance forward (dist=%.3f)" % [seed, i, dist]
		)

		prev = cur

func _check_determinism() -> void:
	var seed := 20260717
	var a := EndlessGenerator.new(seed)
	a.ensure(BLOCK_COUNT)
	var b := EndlessGenerator.new(seed)
	b.ensure(BLOCK_COUNT)

	var identical := true
	for i in range(BLOCK_COUNT):
		var ca: Vector3 = a.blocks[i].center
		var cb: Vector3 = b.blocks[i].center
		var sa: Vector2 = a.blocks[i].size
		var sb: Vector2 = b.blocks[i].size
		if ca != cb or sa != sb:
			identical = false
			break
	_check(identical, "same seed must reproduce identical block positions and sizes")

	# Reset must reproduce the same sequence too.
	var first_center: Vector3 = a.blocks[10].center
	a.reset()
	a.ensure(BLOCK_COUNT)
	_check(a.blocks[10].center == first_center, "reset() must reproduce identical layout")

func _check_variety() -> void:
	var a := EndlessGenerator.new(1)
	a.ensure(100)
	var b := EndlessGenerator.new(2)
	b.ensure(100)

	var differs := false
	for i in range(100):
		if a.blocks[i].center != b.blocks[i].center:
			differs = true
			break
	_check(differs, "different seeds must produce different layouts")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
	printerr("FAIL: " + message)
