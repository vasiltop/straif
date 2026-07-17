class_name EndlessGenerator extends RefCounted

# Pure, seed-deterministic generator for the endless bhop map (map_reverie).
#
# The whole layout is a function of the seed only: every next block is placed
# using an assumed MODEL SPEED (built up from a min-speed floor and ramped with
# the block index), NOT the player's live velocity. Blocks are always makeable
# IF the player keeps their speed at or above the model speed. This class is
# shared by the runtime map (src/maps/endless_bhop.gd) and the headless
# determinism/solvability self-test so the test validates the real code.
#
# Movement constants mirror src/player/player.gd. Do not change them without
# re-checking that generated gaps stay clearable.
const JUMP_FORCE := 4.0
const GRAVITY := 12.0

# Model speed floor and difficulty ramp. The ground cap is 5.5 u/s but bhop
# air-strafing lets planar speed grow past it, so the floor sits slightly above.
const MIN_MODEL_SPEED := 5.8
const MAX_MODEL_SPEED := 9.0
const SPEED_RAMP := 0.02

# Fraction of the maximum makeable reach we actually place the next block at.
# Staying below 1.0 is the safety margin that keeps every block clearable.
const MIN_PLACE_FRAC := 0.70
const MAX_PLACE_FRAC := 0.82

# Vertical step limits (relative to the previous block top).
# The jump peak rise is JUMP_FORCE^2 / (2 * GRAVITY) = 0.667u; up steps stay
# well below that so the player clears them on the way down.
const MAX_UP_STEP := 0.45
const MIN_DOWN_STEP := -1.2
const MAX_DOWN_STEP := -0.3

# Turn capability per block (radians). Reduced at higher speed where turning is
# harder. Kept modest so air-strafing can always follow the path.
const MAX_TURN_LOW := 0.30
const MAX_TURN_HIGH := 0.15

# Where generation starts: the front edge of the authored spawn platform.
const START_Z := -8.0

var seed_value: int
var rng := RandomNumberGenerator.new()
var blocks: Array[Dictionary] = []

var _prev_xz: Vector2
var _prev_top_y: float
var _heading: Vector2

func _init(run_seed: int) -> void:
	seed_value = run_seed
	reset()

func reset() -> void:
	rng.seed = seed_value
	blocks.clear()
	_prev_xz = Vector2(0.0, START_Z)
	_prev_top_y = 0.0
	_heading = Vector2(0.0, -1.0)

# Jump airtime to land at a top that is delta_y above the launch top.
# Solves 4t - 6t^2 = delta_y for the later positive root.
static func hop_time(delta_y: float) -> float:
	var disc := JUMP_FORCE * JUMP_FORCE - 2.0 * GRAVITY * delta_y
	if disc < 0.0:
		disc = 0.0
	return (JUMP_FORCE + sqrt(disc)) / GRAVITY

# Maximum horizontal reach at planar speed s for a step of delta_y.
static func max_reach(s: float, delta_y: float) -> float:
	return s * hop_time(delta_y)

static func model_speed(index: int) -> float:
	return clampf(MIN_MODEL_SPEED + float(index) * SPEED_RAMP, MIN_MODEL_SPEED, MAX_MODEL_SPEED)

static func _max_turn(s: float) -> float:
	var f := clampf(inverse_lerp(MIN_MODEL_SPEED, MAX_MODEL_SPEED, s), 0.0, 1.0)
	return lerpf(MAX_TURN_LOW, MAX_TURN_HIGH, f)

# Ensure at least `count` blocks have been generated. Sequential and
# deterministic: never regenerate an existing block.
func ensure(count: int) -> void:
	while blocks.size() < count:
		_generate_next()

func get_block(index: int) -> Dictionary:
	ensure(index + 1)
	return blocks[index]

func _pick_size(turn: float, delta_y: float) -> Vector2:
	# Bigger landing pads after turns or steps so the player has room to recover.
	var base := rng.randf_range(2.6, 3.6)
	var extra := 0.0
	if absf(turn) > 0.18 or absf(delta_y) > 0.25:
		extra = rng.randf_range(0.8, 1.8)
	var sx := base + extra
	var sz := base + extra
	# Occasionally stretch a platform along one axis for variety.
	var stretch := rng.randf()
	if stretch < 0.2:
		sx += rng.randf_range(1.0, 2.5)
	elif stretch < 0.4:
		sz += rng.randf_range(1.0, 2.5)
	return Vector2(sx, sz)

func _generate_next() -> void:
	var i := blocks.size()
	var s := model_speed(i)

	var delta_y := 0.0
	var r := rng.randf()
	if i < 2:
		delta_y = 0.0
	elif r < 0.55:
		delta_y = 0.0
	elif r < 0.75:
		delta_y = rng.randf_range(0.12, MAX_UP_STEP)
	else:
		delta_y = rng.randf_range(MIN_DOWN_STEP, MAX_DOWN_STEP)

	var max_turn := _max_turn(s)
	var turn := 0.0
	if i >= 1:
		turn = rng.randf_range(-max_turn, max_turn)
	_heading = _heading.rotated(turn).normalized()

	var reach := max_reach(s, delta_y)
	var place := rng.randf_range(MIN_PLACE_FRAC, MAX_PLACE_FRAC)
	if max_turn > 0.0:
		place *= lerpf(1.0, 0.9, clampf(absf(turn) / max_turn, 0.0, 1.0))
	var gap := reach * place

	var new_xz := _prev_xz + _heading * gap
	var top_y := _prev_top_y + delta_y
	var size := _pick_size(turn, delta_y)

	blocks.append({
		"index": i,
		"center": Vector3(new_xz.x, top_y, new_xz.y),
		"size": Vector2(size.x, size.y),
		"heading": _heading.angle(),
		"delta_y": delta_y,
		"gap": gap,
		"model_speed": s,
	})

	_prev_xz = new_xz
	_prev_top_y = top_y
