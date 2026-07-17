class_name EndlessGenerator extends ProceduralGenerator

# Endless bhop pipeline: a pure, seed-deterministic ProceduralGenerator.
#
# The whole layout is a function of the seed only: every next block is placed
# using an assumed MODEL SPEED (built up from a min-speed floor and ramped with
# the block index), NOT the player's live velocity. Blocks are always makeable
# IF the player keeps their speed at or above the model speed. This pipeline is
# shared by the runtime map (src/maps/procedural/procedural_map.gd) and the
# headless determinism/solvability self-test so the test validates real code.
#
# Movement constants mirror src/player/player.gd. Do not change them without
# re-checking that generated gaps stay clearable.
const JUMP_FORCE := 4.0
const GRAVITY := 12.0

# Model speed floor and difficulty ramp. The ground cap is 5.5 u/s but bhop
# air-strafing lets planar speed grow past it, so the floor sits slightly above.
const MIN_MODEL_SPEED := 6.0
const MAX_MODEL_SPEED := 9.0
const SPEED_RAMP := 0.02

# Fraction of the maximum makeable reach used for the AIR gap the player flies
# over (edge-to-edge empty space between blocks). Staying below 1.0 is the
# safety margin that keeps every jump clearable at the model speed; block depth
# then catches faster players who overshoot.
const MIN_PLACE_FRAC := 0.55
const MAX_PLACE_FRAC := 0.78

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

# Where generation starts: the front edge of the authored spawn platform
# (centered at origin, 20 deep, so its leading -Z edge sits at z = -10).
const START_Z := -10.0

var _prev_xz: Vector2
var _prev_top_y: float
var _prev_radius: float
var _heading: Vector2

func reset() -> void:
	super.reset()
	_prev_xz = Vector2(0.0, START_Z)
	_prev_top_y = 0.0
	_prev_radius = 0.0
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

# Effective footprint radius of a block along the path. Blocks are near-square
# and turns are small, so the average half-extent is a good approximation and,
# crucially, is used identically by the runtime, the placement math, and the
# self-test so the air gaps stay exact.
static func block_radius(size: Vector2) -> float:
	return (size.x + size.y) * 0.25

static func model_speed(index: int) -> float:
	return clampf(MIN_MODEL_SPEED + float(index) * SPEED_RAMP, MIN_MODEL_SPEED, MAX_MODEL_SPEED)

static func _max_turn(s: float) -> float:
	var f := clampf(inverse_lerp(MIN_MODEL_SPEED, MAX_MODEL_SPEED, s), 0.0, 1.0)
	return lerpf(MAX_TURN_LOW, MAX_TURN_HIGH, f)

# Ensure at least `count` blocks have been generated and get_block() are
# inherited from ProceduralGenerator; only _generate_next() is pipeline-specific.

func _pick_size(turn: float, delta_y: float) -> Vector2:
	# Landing pads are kept modest so there is always visible air between blocks,
	# but grow a little after turns or steps so the player has room to recover.
	var base := rng.randf_range(1.8, 2.6)
	var extra := 0.0
	if absf(turn) > 0.18 or absf(delta_y) > 0.25:
		extra = rng.randf_range(0.5, 1.1)
	var sx := base + extra
	var sz := base + extra
	# Occasionally stretch a platform along one axis for variety.
	var stretch := rng.randf()
	if stretch < 0.2:
		sx += rng.randf_range(0.8, 1.8)
	elif stretch < 0.4:
		sz += rng.randf_range(0.8, 1.8)
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

	# The player flies across the AIR gap (empty span between block edges); place
	# it at a fraction of the makeable reach so keeping speed up always clears it.
	var reach := max_reach(s, delta_y)
	var place := rng.randf_range(MIN_PLACE_FRAC, MAX_PLACE_FRAC)
	if max_turn > 0.0:
		place *= lerpf(1.0, 0.9, clampf(absf(turn) / max_turn, 0.0, 1.0))
	var air_gap := reach * place

	var size := _pick_size(turn, delta_y)
	var radius := block_radius(size)

	# Center-to-center distance = previous half + air gap + this half so the
	# empty span the player jumps is exactly `air_gap`.
	var center_gap := _prev_radius + air_gap + radius
	var new_xz := _prev_xz + _heading * center_gap
	var top_y := _prev_top_y + delta_y

	blocks.append({
		"index": i,
		"center": Vector3(new_xz.x, top_y, new_xz.y),
		"size": Vector2(size.x, size.y),
		"radius": radius,
		"heading": _heading.angle(),
		"delta_y": delta_y,
		"air_gap": air_gap,
		"model_speed": s,
	})

	_prev_xz = new_xz
	_prev_top_y = top_y
	_prev_radius = radius
