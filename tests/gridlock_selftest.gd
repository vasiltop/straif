extends SceneTree

# Headless determinism + solvability self-test for the Grid City procedural
# endless map (map_gridlock). Block placement uses the model speed (not the live
# player velocity), so the whole layout is a pure function of the seed. This test:
#   (a) generates hundreds of blocks for several seeds and asserts EVERY
#       consecutive gap is clearable at the model speed with margin, leaves real
#       air between the along-heading edges, keeps up-steps within the cap, and
#       keeps every heading strictly cardinal, and
#   (b) asserts the same seed reproduces identical layouts while different seeds
#       diverge.
#
# Run: godot --headless --script res://tests/gridlock_selftest.gd

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
	var gen := GridlockGenerator.new(seed)
	gen.ensure(BLOCK_COUNT)

	_check(gen.blocks.size() == BLOCK_COUNT, "seed %d should generate %d blocks" % [seed, BLOCK_COUNT])

	var prev := Vector3(0.0, 0.0, GridlockGenerator.START_Z)
	for i in range(BLOCK_COUNT):
		var spec: Dictionary = gen.blocks[i]
		var cur: Vector3 = spec.center
		var dy := cur.y - prev.y

		var dx := cur.x - prev.x
		var dz := cur.z - prev.z
		var dist := sqrt(dx * dx + dz * dz)

		# Along-heading half-extents (exact for long axis-aligned slabs), stored
		# by the generator; edge-to-edge empty span the player flies over.
		var prev_half: float = spec.prev_half
		var this_half: float = spec.half_along
		var air := dist - prev_half - this_half

		var s: float = spec.model_speed
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
			dy <= GridlockGenerator.MAX_UP_STEP + 0.001,
			"seed %d block %d up-step %.3f exceeds max %.3f" % [seed, i, dy, GridlockGenerator.MAX_UP_STEP]
		)

		# Heading must always be exactly one of the four cardinal unit vectors.
		var h: Vector2 = spec.heading
		var cardinal := (
			(absf(absf(h.x) - 1.0) < 1e-6 and absf(h.y) < 1e-6)
			or (absf(h.x) < 1e-6 and absf(absf(h.y) - 1.0) < 1e-6)
		)
		_check(cardinal, "seed %d block %d heading %s is not cardinal" % [seed, i, str(h)])

		prev = cur

func _check_determinism() -> void:
	var seed := 20260717
	var a := GridlockGenerator.new(seed)
	a.ensure(BLOCK_COUNT)
	var b := GridlockGenerator.new(seed)
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
	var a := GridlockGenerator.new(1)
	a.ensure(100)
	var b := GridlockGenerator.new(2)
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
