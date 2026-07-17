extends SceneTree

# Headless determinism + solvability self-test for the Canyon Descent procedural
# map (map_cascade). Block placement uses the model speed (not the live player
# velocity), so the whole layout is a pure function of the seed. This test:
#   (a) generates hundreds of beams for several seeds and asserts EVERY
#       consecutive gap is clearable at the model speed with margin, using the
#       BEAM along-path half-extents (length / 2) rather than the averaged
#       BhopPhysics.block_radius (which is wrong for long thin beams),
#   (b) asserts real air (> 0.1) between beam ends and up-steps within cap,
#   (c) asserts the same seed reproduces identical layouts while different seeds
#       diverge, and
#   (d) asserts the course trends NET DOWNWARD.
#
# Run: godot --headless --script res://tests/cascade_selftest.gd

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
	var gen := CascadeGenerator.new(seed)
	gen.ensure(BLOCK_COUNT)

	_check(gen.blocks.size() == BLOCK_COUNT, "seed %d should generate %d beams" % [seed, BLOCK_COUNT])

	var prev := Vector3(0.0, 0.0, CascadeGenerator.START_Z)
	var prev_half := 0.0
	var down_steps := 0
	for i in range(BLOCK_COUNT):
		var spec: Dictionary = gen.blocks[i]
		var cur: Vector3 = spec.center
		var dy := cur.y - prev.y

		var dx := cur.x - prev.x
		var dz := cur.z - prev.z
		var dist := sqrt(dx * dx + dz * dz)

		# Along-path half-extent of a beam is length / 2, stored as `radius`.
		var this_half: float = spec.radius
		_check(
			absf(this_half - spec.size.x * 0.5) < 0.0001,
			"seed %d beam %d radius must equal length/2" % [seed, i]
		)
		# Edge-to-edge empty span the player actually flies over.
		var air := dist - prev_half - this_half

		var s := CascadeGenerator.model_speed(i)
		var reach := BhopPhysics.max_reach(s, dy)

		_check(
			air <= reach * SAFETY,
			"seed %d beam %d air gap %.3f exceeds clearable reach %.3f (dy=%.3f, s=%.2f)" % [seed, i, air, reach * SAFETY, dy, s]
		)
		_check(
			air > 0.1,
			"seed %d beam %d should leave real air between beam ends (air=%.3f)" % [seed, i, air]
		)
		_check(
			dy <= CascadeGenerator.MAX_UP_STEP + 0.001,
			"seed %d beam %d up-step %.3f exceeds max %.3f" % [seed, i, dy, CascadeGenerator.MAX_UP_STEP]
		)
		_check(
			spec.size.y >= CascadeGenerator.MIN_BEAM_WIDTH - 0.001 and spec.size.y <= CascadeGenerator.MAX_BEAM_WIDTH + 0.001,
			"seed %d beam %d width %.3f out of narrow range" % [seed, i, spec.size.y]
		)
		if dy < 0.0:
			down_steps += 1

		prev = cur
		prev_half = this_half

	# Net downward: the course must end well below where it started, and most
	# steps must be descents.
	var end_center: Vector3 = gen.blocks[BLOCK_COUNT - 1].center
	var net := end_center.y
	_check(net < -20.0, "seed %d net elevation should trend downward (end y=%.1f)" % [seed, net])
	_check(
		down_steps > BLOCK_COUNT / 2,
		"seed %d most steps should descend (down=%d/%d)" % [seed, down_steps, BLOCK_COUNT]
	)

func _check_determinism() -> void:
	var seed := 20260717
	var a := CascadeGenerator.new(seed)
	a.ensure(BLOCK_COUNT)
	var b := CascadeGenerator.new(seed)
	b.ensure(BLOCK_COUNT)

	var identical := true
	for i in range(BLOCK_COUNT):
		var ca: Vector3 = a.blocks[i].center
		var cb: Vector3 = b.blocks[i].center
		var sa: Vector2 = a.blocks[i].size
		var sb: Vector2 = b.blocks[i].size
		var ya: float = a.blocks[i].yaw
		var yb: float = b.blocks[i].yaw
		if ca != cb or sa != sb or ya != yb:
			identical = false
			break
	_check(identical, "same seed must reproduce identical beam positions, sizes, and yaws")

	var first_center: Vector3 = a.blocks[10].center
	a.reset()
	a.ensure(BLOCK_COUNT)
	_check(a.blocks[10].center == first_center, "reset() must reproduce identical layout")

func _check_variety() -> void:
	var a := CascadeGenerator.new(1)
	a.ensure(100)
	var b := CascadeGenerator.new(2)
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
