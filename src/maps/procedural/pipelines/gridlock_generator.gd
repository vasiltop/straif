class_name GridlockGenerator extends ProceduralGenerator

const PIPELINE_NAME := "gridlock"

# Grid City (map_gridlock): a discrete CARDINAL grid-walk procedural pipeline.
#
# The whole layout is a pure function of the seed. Heading is always one of the
# four cardinal unit vectors (+x, -x, +z, -z). Each step, with high probability
# the walk continues STRAIGHT (producing long rooftop straightaways); otherwise
# it turns 90 degrees LEFT or RIGHT — never a 180 degree reversal. This reads as
# running across Manhattan-style city rooftops.
#
# Placement uses an assumed MODEL SPEED (a floor plus a gentle index ramp), not
# the player's live velocity, so every gap is makeable IF the player keeps their
# speed at or above the model speed. Because a 90 degree cardinal turn is a large
# heading change, TURN blocks use a SHORTER air gap and a larger, more forgiving
# landing slab, and stay flat. Straightaways can carry more speed and stretch the
# slab along the heading.
#
# Objects are axis-aligned rectangular SLABS (shape "box", yaw 0). Since slabs
# can be long, the gap math uses the half-extent ALONG THE HEADING (size.x when
# the heading runs along X, size.y when it runs along Z) rather than the averaged
# BhopPhysics.block_radius, so edge-to-edge air stays exact for long straights.
#
# Jump kinematics (hop_time, max_reach) come from BhopPhysics, shared with every
# other pipeline and the headless self-test so the makeable-gap math is identical.

# Model speed floor and gentle difficulty ramp. Turning 90 degrees at very high
# speed is not realistic, so the cap is kept modest.
const MIN_MODEL_SPEED := 5.5
const MAX_MODEL_SPEED := 7.5
const SPEED_RAMP := 0.015

# Fraction of the maximum makeable reach used for the AIR gap (edge-to-edge empty
# span). Straights allow a wider gap; turns are pulled in for a forgiving landing.
const STRAIGHT_PLACE_MIN := 0.55
const STRAIGHT_PLACE_MAX := 0.78
const TURN_PLACE_MIN := 0.40
const TURN_PLACE_MAX := 0.55

# Vertical steps are quantized to CITY_LEVEL for a stacked city-levels look.
# Up-steps stay one level (0.25u), well below BhopPhysics.JUMP_PEAK_RISE (0.667u)
# so the player clears them on the way down. Down-steps may drop several levels.
const CITY_LEVEL := 0.25
const MAX_UP_STEP := 0.45
const DOWN_LEVELS := [-0.25, -0.5, -0.75, -1.0]

# Turn cadence: never turn two blocks in a row so turns are not cramped, and turn
# with this probability once a turn is allowed. High straight probability yields
# the long city straightaways.
const MIN_STRAIGHT_AFTER_TURN := 2
const TURN_PROB := 0.30

# Slab footprint ranges (in "along the heading" / "across the heading" terms).
const ROOF_CROSS_MIN := 2.2
const ROOF_CROSS_MAX := 3.2
const STRAIGHT_ALONG_MIN := 2.6
const STRAIGHT_ALONG_MAX := 6.0
const TURN_SIDE_MIN := 3.2
const TURN_SIDE_MAX := 4.6
const PLAZA_PROB := 0.06
const PLAZA_MIN := 6.0
const PLAZA_MAX := 9.0

# Where generation starts: the front edge of the authored spawn platform
# (centered at origin, 20 deep, so its leading -Z edge sits at z = -10).
const START_Z := -10.0

var _prev_xz: Vector2
var _prev_top_y: float
var _prev_size: Vector2
var _heading: Vector2
var _straight_run: int

func reset() -> void:
	super.reset()
	_prev_xz = Vector2(0.0, START_Z)
	_prev_top_y = 0.0
	# A zero-footprint "previous" so the first gap is measured from the spawn
	# front edge at z = -10, not from the spawn platform center.
	_prev_size = Vector2(0.0, 0.0)
	_heading = Vector2(0.0, -1.0)
	_straight_run = MIN_STRAIGHT_AFTER_TURN

static func model_speed(index: int) -> float:
	return clampf(MIN_MODEL_SPEED + float(index) * SPEED_RAMP, MIN_MODEL_SPEED, MAX_MODEL_SPEED)

# Cardinal 90 degree turns kept exact (integer components), so headings never
# drift off the four cardinal axes.
static func _turn_right(h: Vector2) -> Vector2:
	return Vector2(-h.y, h.x)

static func _turn_left(h: Vector2) -> Vector2:
	return Vector2(h.y, -h.x)

# Half-extent of a slab along the given cardinal heading.
static func half_along(heading: Vector2, size: Vector2) -> float:
	if absf(heading.x) > 0.5:
		return size.x * 0.5
	return size.y * 0.5

# Map an (along-heading, across-heading) footprint to world (size.x, size.y).
func _oriented_size(along: float, across: float) -> Vector2:
	if absf(_heading.x) > 0.5:
		return Vector2(along, across)
	return Vector2(across, along)

func _generate_next() -> void:
	var i := blocks.size()
	var s := model_speed(i)

	# --- Heading: straight or a 90 degree cardinal turn --------------------
	var is_turn := false
	if i >= 1 and _straight_run >= MIN_STRAIGHT_AFTER_TURN and rng.randf() < TURN_PROB:
		is_turn = true
		if rng.randf() < 0.5:
			_heading = _turn_left(_heading)
		else:
			_heading = _turn_right(_heading)
		_straight_run = 0
	else:
		_straight_run += 1

	# --- Vertical step (quantized city levels; turns stay flat) ------------
	var delta_y := 0.0
	if i >= 2 and not is_turn:
		var r := rng.randf()
		if r < 0.62:
			delta_y = 0.0
		elif r < 0.80:
			delta_y = CITY_LEVEL
		else:
			delta_y = DOWN_LEVELS[rng.randi_range(0, DOWN_LEVELS.size() - 1)]

	# --- Slab footprint ----------------------------------------------------
	var size: Vector2
	var is_plaza := false
	if not is_turn and rng.randf() < PLAZA_PROB:
		is_plaza = true
		var pw := rng.randf_range(PLAZA_MIN, PLAZA_MAX)
		var pd := rng.randf_range(PLAZA_MIN, PLAZA_MAX)
		size = Vector2(pw, pd)
	elif is_turn:
		# Forgiving, roughly square landing pad to recover the turn.
		var side := rng.randf_range(TURN_SIDE_MIN, TURN_SIDE_MAX)
		var side2 := rng.randf_range(TURN_SIDE_MIN, TURN_SIDE_MAX)
		size = Vector2(side, side2)
	else:
		var across := rng.randf_range(ROOF_CROSS_MIN, ROOF_CROSS_MAX)
		var along := rng.randf_range(STRAIGHT_ALONG_MIN, STRAIGHT_ALONG_MAX)
		size = _oriented_size(along, across)

	# --- Air gap (fraction of makeable reach; shorter through turns) -------
	var reach := BhopPhysics.max_reach(s, delta_y)
	var place: float
	if is_turn:
		place = rng.randf_range(TURN_PLACE_MIN, TURN_PLACE_MAX)
	else:
		place = rng.randf_range(STRAIGHT_PLACE_MIN, STRAIGHT_PLACE_MAX)
	var air_gap := maxf(reach * place, 0.3)

	# --- Placement along the current cardinal heading ----------------------
	var prev_half := half_along(_heading, _prev_size)
	var this_half := half_along(_heading, size)
	var center_gap := prev_half + air_gap + this_half
	var new_xz := _prev_xz + _heading * center_gap
	var top_y := _prev_top_y + delta_y

	blocks.append({
		"index": i,
		"center": Vector3(new_xz.x, top_y, new_xz.y),
		"size": Vector2(size.x, size.y),
		"shape": "box",
		"yaw": 0.0,
		"heading": Vector2(_heading.x, _heading.y),
		"is_turn": is_turn,
		"is_plaza": is_plaza,
		"delta_y": delta_y,
		"air_gap": air_gap,
		"prev_half": prev_half,
		"half_along": this_half,
		"model_speed": s,
	})

	_prev_xz = new_xz
	_prev_top_y = top_y
	_prev_size = size
