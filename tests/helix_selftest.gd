extends SceneTree

# Headless determinism + solvability self-test for the procedural ascending
# spiral map (map_helix). Because block placement uses the model speed (not the
# live player velocity), the whole corkscrew is a pure function of the seed.
# This test:
#   (a) generates hundreds of blocks for several seeds and asserts EVERY
#       consecutive air gap is clearable at the model speed with margin, leaves
#       real air between pad edges, and every up-step stays under the cap, and
#   (b) asserts the same seed reproduces identical block positions, while
#       different seeds diverge.
#
# Run: godot --headless --script res://tests/helix_selftest.gd

const SEEDS := [1, 42, 1337, 999999, 2024, 7]
const BLOCK_COUNT := 400
const SAFETY := 0.9

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
	var gen := HelixGenerator.new(seed)
	gen.ensure(BLOCK_COUNT)

	_check(gen.blocks.size() == BLOCK_COUNT, "seed %d should generate %d blocks" % [seed, BLOCK_COUNT])

	var prev := Vector3(0.0, 0.0, HelixGenerator.START_Z)
	var prev_radius := 0.0
	for i in range(BLOCK_COUNT):
		var spec: Dictionary = gen.blocks[i]
		var cur: Vector3 = spec.center
		var dy := cur.y - prev.y

		var dx := cur.x - prev.x
		var dz := cur.z - prev.z
		var dist := sqrt(dx * dx + dz * dz)

		var this_radius: float = spec.radius
		# Edge-to-edge empty span the player actually flies over.
		var air := dist - prev_radius - this_radius

		var s := HelixGenerator.model_speed(i)
		var reach := BhopPhysics.max_reach(s, dy)

		_check(
			air <= reach * SAFETY,
			"seed %d block %d air gap %.3f exceeds clearable reach %.3f (dy=%.3f, s=%.2f)" % [seed, i, air, reach * SAFETY, dy, s]
		)
		_check(
			air > 0.1,
			"seed %d block %d should leave real air between edges (air=%.3f)" % [seed, i, air]
		)
		_check(
			dy <= HelixGenerator.MAX_UP_STEP + 0.001,
			"seed %d block %d up-step %.3f exceeds max %.3f" % [seed, i, dy, HelixGenerator.MAX_UP_STEP]
		)
		_check(
			dy >= -0.001,
			"seed %d block %d should never step down (dy=%.3f)" % [seed, i, dy]
		)

		prev = cur
		prev_radius = this_radius

func _check_determinism() -> void:
	var seed := 20260717
	var a := HelixGenerator.new(seed)
	a.ensure(BLOCK_COUNT)
	var b := HelixGenerator.new(seed)
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
	var a := HelixGenerator.new(1)
	a.ensure(100)
	var b := HelixGenerator.new(2)
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
