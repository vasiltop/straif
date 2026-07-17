class_name HelixGenerator extends ProceduralGenerator

const PIPELINE_NAME := "helix"

# Ascending-spiral (corkscrew tower) pipeline: a pure, seed-deterministic
# ProceduralGenerator. Blocks are round cylinder pads placed on a circle of
# radius R around a FIXED vertical central axis. Each block advances an angular
# position `theta` by a per-block angle `dtheta` (constant sign = one spin
# direction), so the player's heading — the circle tangent — rotates by ~dtheta
# per block and the course screws upward around the axis.
#
# Everything is a pure function of the seed via `self.rng`, so the runtime
# (procedural_map.gd) and the headless self-test reproduce identical layouts.
#
# Makeability is guaranteed by construction. For each block we:
#   * pick a model speed (index-ramped, NOT the live velocity) and its turn cap,
#   * pick the axis radius R (tightening with index but kept large enough that a
#     dtheta within the turn cap can leave a real, clearable air gap),
#   * choose a target air gap as a fraction of the makeable reach, and
#   * SOLVE dtheta from the exact chord on the fixed-axis circle so the
#     edge-to-edge air gap lands inside (0.1, max_reach * SAFETY].
# Jump kinematics (hop_time, max_reach, block_radius) come from BhopPhysics,
# mirrored from src/player/player.gd, so the makeable-gap math matches every
# other procedural map.

# Model speed floor and difficulty ramp (same envelope as the endless pipeline:
# bhop air-strafing lets planar speed grow past the 5.5 u/s ground cap).
const MIN_MODEL_SPEED := 6.0
const MAX_MODEL_SPEED := 9.0
const SPEED_RAMP := 0.02

# Per-block turn capability (radians) = |dtheta|. Reduced at higher speed where
# air-strafe turning is harder. Kept inside the ~0.18..0.30 rad band so the
# player can always follow the corkscrew, and never so small that avoiding pad
# overlap would force an unreasonably wide radius.
const MAX_TURN_LOW := 0.30
const MAX_TURN_HIGH := 0.24
const DTHETA_MIN := 0.12

# One spin direction for the whole tower (constant sign).
const SPIN := 1.0

# Axis radius: tightens with index (the spiral visibly draws in), then holds at
# whatever the turn cap needs so pads never touch. Expect R to settle ~12..15.
const R_START := 15.0
const R_END := 12.0
const R_RAMP := 0.006
const R_MIN := 10.0
const R_MAX := 16.5

# Air gap (edge-to-edge empty span the player flies over) as a fraction of the
# makeable reach. Staying well below 1.0 is the safety margin; on this map the
# geometry envelope keeps the real gaps comfortably small (turning precision,
# not gap length, is the challenge).
const MIN_PLACE_FRAC := 0.42
const MAX_PLACE_FRAC := 0.68
const AIR_MIN := 0.35
const AIR0_MAX := 1.5

# Round pads. Radius stays modest so there is always visible air between pads;
# an occasional wider pad gives a rest platform for rhythm.
const PAD_MIN := 1.1
const PAD_MAX := 1.45
const REST_PROB := 0.12
const REST_MIN := 1.6
const REST_MAX := 1.75

# Vertical precision: a small positive climb each block (occasionally a flat
# step). Always kept below BhopPhysics.JUMP_PEAK_RISE (0.667u) with margin so
# the player clears the up-step on the way down.
const MAX_UP_STEP := 0.45

# Where generation starts: the front (-Z) edge of the authored spawn platform,
# which sits centered at origin 20 deep, so its leading edge is at z = -10.
const START_Z := -10.0

var _axis: Vector2
var _theta: float
var _prev_xz: Vector2
var _prev_top: float
var _prev_radius: float
var _prev_axis_r: float

func reset() -> void:
	super.reset()
	_axis = Vector2.ZERO
	_theta = 0.0
	_prev_xz = Vector2(0.0, START_Z)
	_prev_top = 0.0
	_prev_radius = 0.0
	_prev_axis_r = 0.0

static func model_speed(index: int) -> float:
	return clampf(MIN_MODEL_SPEED + float(index) * SPEED_RAMP, MIN_MODEL_SPEED, MAX_MODEL_SPEED)

static func _max_turn(s: float) -> float:
	var f := clampf(inverse_lerp(MIN_MODEL_SPEED, MAX_MODEL_SPEED, s), 0.0, 1.0)
	return lerpf(MAX_TURN_LOW, MAX_TURN_HIGH, f)

# Straight-line distance between two samples on the same fixed-axis circle: one
# at radius ra, the other at radius rb, separated by angle dth.
static func _circle_dist(ra: float, rb: float, dth: float) -> float:
	return sqrt(maxf(ra * ra + rb * rb - 2.0 * ra * rb * cos(dth), 0.0))

func _pick_radius(is_rest: bool) -> float:
	if is_rest:
		return rng.randf_range(REST_MIN, REST_MAX)
	return rng.randf_range(PAD_MIN, PAD_MAX)

func _pick_delta_y(i: int) -> float:
	if i < 2:
		return 0.0
	if rng.randf() < 0.18:
		return 0.0
	return clampf(rng.randf_range(0.15, MAX_UP_STEP), 0.0, MAX_UP_STEP)

func _generate_next() -> void:
	var i := blocks.size()
	var s := model_speed(i)

	var is_rest := i >= 2 and rng.randf() < REST_PROB
	var r := _pick_radius(is_rest)
	var dy := _pick_delta_y(i)

	if i == 0:
		_emit_first(s, r)
		return

	var mt := _max_turn(s)

	# Axis radius: tighten with index, but keep it large enough that a dtheta
	# within the turn cap can still leave AIR_MIN of real air between pad edges.
	var denom := sqrt(maxf(2.0 * (1.0 - cos(mt)), 1e-6))
	var r_needed := (_prev_radius + r + AIR_MIN) / denom
	var r_ramp := lerpf(R_START, R_END, clampf(float(i) * R_RAMP, 0.0, 1.0))
	var axis_r := clampf(maxf(r_ramp, r_needed + 0.25), R_MIN, R_MAX)

	# Target air gap as a fraction of the makeable reach, then clamp into the
	# geometry envelope reachable within [DTHETA_MIN, max_turn].
	var reach := BhopPhysics.max_reach(s, dy)
	var place := rng.randf_range(MIN_PLACE_FRAC, MAX_PLACE_FRAC)
	var air_target := reach * place

	var d_min := _circle_dist(_prev_axis_r, axis_r, DTHETA_MIN)
	var d_max := _circle_dist(_prev_axis_r, axis_r, mt)
	var chord := clampf(air_target + _prev_radius + r, maxf(d_min, 0.0), d_max)
	chord = clampf(chord, d_min, d_max)

	# Solve the advance angle for that chord on the fixed-axis circle.
	var cos_dth := (_prev_axis_r * _prev_axis_r + axis_r * axis_r - chord * chord) / (2.0 * _prev_axis_r * axis_r)
	var dtheta := clampf(acos(clampf(cos_dth, -1.0, 1.0)), DTHETA_MIN, mt)

	_theta += SPIN * dtheta
	var new_xz := _axis + Vector2(cos(_theta), sin(_theta)) * axis_r
	var top_y := _prev_top + dy

	# Real edge-to-edge air the player flies over, from the actual placement.
	var air_gap := new_xz.distance_to(_prev_xz) - _prev_radius - r

	blocks.append({
		"index": i,
		"center": Vector3(new_xz.x, top_y, new_xz.y),
		"size": Vector2(2.0 * r, 2.0 * r),
		"radius": r,
		"shape": "cylinder",
		"theta": _theta,
		"delta_y": dy,
		"air_gap": air_gap,
		"model_speed": s,
	})

	_prev_xz = new_xz
	_prev_top = top_y
	_prev_radius = r
	_prev_axis_r = axis_r

# First pad sits straight ahead of the spawn platform front edge (z = -10) with
# a real air gap, tangent pointing forward (-Z). Placing it at theta = PI on a
# circle whose center is offset +X by the radius makes the tangent there face
# -Z, and fixes the vertical axis the rest of the tower spirals around.
func _emit_first(s: float, r: float) -> void:
	var reach := BhopPhysics.max_reach(s, 0.0)
	var place := rng.randf_range(MIN_PLACE_FRAC, MAX_PLACE_FRAC)
	var air0 := clampf(reach * place, AIR_MIN, AIR0_MAX)
	var axis_r := clampf(R_START, R_MIN, R_MAX)

	var g0 := r + air0
	var new_xz := Vector2(0.0, START_Z - g0)
	_axis = Vector2(axis_r, START_Z - g0)
	_theta = PI

	blocks.append({
		"index": 0,
		"center": Vector3(new_xz.x, 0.0, new_xz.y),
		"size": Vector2(2.0 * r, 2.0 * r),
		"radius": r,
		"shape": "cylinder",
		"theta": _theta,
		"delta_y": 0.0,
		"air_gap": air0,
		"model_speed": s,
	})

	_prev_xz = new_xz
	_prev_top = 0.0
	_prev_radius = r
	_prev_axis_r = axis_r
