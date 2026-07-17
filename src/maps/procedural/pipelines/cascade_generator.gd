class_name CascadeGenerator extends ProceduralGenerator

const PIPELINE_NAME := "cascade"

# Canyon Descent pipeline: a pure, seed-deterministic ProceduralGenerator that
# threads NARROW BEAMS down a switchbacking course over a bottomless void.
#
# Like the endless pipeline, the whole layout is a function of the seed only:
# every next beam is placed using an assumed MODEL SPEED (a floor ramped by the
# block index), NOT the player's live velocity, so a gap is always clearable IF
# the player keeps their speed at or above the model speed. This pipeline is
# shared by the runtime map (procedural_map.gd via the `pipeline` export) and the
# headless determinism/solvability self-test, so the test validates real code.
#
# Difficulty flavor (vs. the endless pads):
#   * Beams instead of near-square pads: long, thin boxes whose LONG axis follows
#     the heading (yaw = heading angle). Landings are tight, so speed management
#     and precise strafing matter far more.
#   * Net DOWNWARD. Most steps drop; note a negative delta_y INCREASES max_reach
#     (hop airtime grows), so descending naturally opens up LONGER gaps.
#   * Periodic HAIRPIN reversals: gentle turns most of the time, punctuated by a
#     short run of sharper same-direction turns that reverses the general heading
#     (a switchback). Every individual heading change stays within air-strafe
#     capability so the path is always followable.
#
# Jump kinematics (hop_time, max_reach) come from BhopPhysics (mirrored from
# src/player/player.gd) so the makeable-gap math is identical across all maps.
# IMPORTANT: BhopPhysics.block_radius averages width+depth and is WRONG for a
# long thin beam, so this pipeline computes the along-path half-extent itself as
# length / 2 for all placement and gap math.

# Model speed floor and difficulty ramp. The ground cap is 5.5 u/s but bhop
# air-strafing lets planar speed grow past it, so the floor sits above it and the
# course assumes the player has built speed by the time gaps widen.
const MIN_MODEL_SPEED := 6.0
const MAX_MODEL_SPEED := 9.5
const SPEED_RAMP := 0.016

# Fraction of the maximum makeable reach used for the AIR gap the player flies
# over (empty span between beam ends). Staying below 1.0 is the safety margin
# that keeps every jump clearable at the model speed.
const MIN_PLACE_FRAC := 0.58
const MAX_PLACE_FRAC := 0.80

# Beam footprint. Long axis runs along the heading; the narrow cross-axis is what
# makes landings punishing.
const MIN_BEAM_LENGTH := 4.0
const MAX_BEAM_LENGTH := 7.0
const MIN_BEAM_WIDTH := 1.2
const MAX_BEAM_WIDTH := 1.8

# Vertical step limits (relative to the previous beam top). Down-steps dominate;
# the rare up-step stays well under BhopPhysics.JUMP_PEAK_RISE (0.667u) so the
# player clears it on the way down.
const MAX_UP_STEP := 0.45
const MIN_DOWN_STEP := -1.5
const MAX_DOWN_STEP := -0.3

# Turn capability per block (radians). Gentle cruising turns between hairpins;
# hairpin turns are sharper but still inside the per-block strafe cap.
const GENTLE_TURN := 0.12
const HAIRPIN_TURN_MIN := 0.28
const HAIRPIN_TURN_MAX := 0.38
const MAX_TURN := 0.40

# Hairpin cadence: blocks of gentle cruising between switchbacks, and how many
# sharp same-direction turns make up one switchback.
const HAIRPIN_GAP_MIN := 12
const HAIRPIN_GAP_MAX := 20
const HAIRPIN_LEN_MIN := 4
const HAIRPIN_LEN_MAX := 6

# Where generation starts: the front edge of the authored spawn platform
# (centered at origin, 20 deep, so its leading -Z edge sits at z = -10).
const START_Z := -10.0

var _prev_xz: Vector2
var _prev_top_y: float
var _prev_half: float
var _heading: Vector2
var _since_hairpin: int
var _next_hairpin_gap: int
var _hairpin_left: int
var _hairpin_dir: float

func reset() -> void:
	super.reset()
	_prev_xz = Vector2(0.0, START_Z)
	_prev_top_y = 0.0
	_prev_half = 0.0
	_heading = Vector2(0.0, -1.0)
	_since_hairpin = 0
	_next_hairpin_gap = rng.randi_range(HAIRPIN_GAP_MIN, HAIRPIN_GAP_MAX)
	_hairpin_left = 0
	_hairpin_dir = 0.0

static func model_speed(index: int) -> float:
	return clampf(MIN_MODEL_SPEED + float(index) * SPEED_RAMP, MIN_MODEL_SPEED, MAX_MODEL_SPEED)

# Pick this beam's vertical step. Net downward with an occasional flat and a rare
# small up-step. The first couple of beams stay flat so they are trivially
# reachable off the wide spawn platform.
func _pick_delta_y(index: int) -> float:
	if index < 2:
		return 0.0
	var r := rng.randf()
	if r < 0.68:
		return rng.randf_range(MIN_DOWN_STEP, MAX_DOWN_STEP)
	elif r < 0.85:
		return 0.0
	else:
		return rng.randf_range(0.12, MAX_UP_STEP)

# Advance the heading. Between hairpins the course drifts with gentle turns; every
# so often it commits to a short run of sharp same-direction turns that reverses
# the general heading (a switchback). Every step is capped at MAX_TURN so the
# player's air-strafing can always follow it.
func _advance_heading(index: int) -> void:
	if index == 0:
		return
	var turn := 0.0
	if _hairpin_left > 0:
		turn = _hairpin_dir * rng.randf_range(HAIRPIN_TURN_MIN, HAIRPIN_TURN_MAX)
		_hairpin_left -= 1
	elif _since_hairpin >= _next_hairpin_gap:
		_hairpin_dir = 1.0 if rng.randf() < 0.5 else -1.0
		_hairpin_left = rng.randi_range(HAIRPIN_LEN_MIN, HAIRPIN_LEN_MAX) - 1
		_since_hairpin = 0
		_next_hairpin_gap = rng.randi_range(HAIRPIN_GAP_MIN, HAIRPIN_GAP_MAX)
		turn = _hairpin_dir * rng.randf_range(HAIRPIN_TURN_MIN, HAIRPIN_TURN_MAX)
	else:
		turn = rng.randf_range(-GENTLE_TURN, GENTLE_TURN)
		_since_hairpin += 1
	turn = clampf(turn, -MAX_TURN, MAX_TURN)
	_heading = _heading.rotated(turn).normalized()

func _generate_next() -> void:
	var i := blocks.size()
	var s := model_speed(i)

	var delta_y := _pick_delta_y(i)
	_advance_heading(i)

	# The player flies across the AIR gap (empty span between beam ends); place it
	# at a fraction of the makeable reach so keeping speed up always clears it. A
	# negative delta_y grows max_reach, so descents naturally open longer gaps.
	var reach := BhopPhysics.max_reach(s, delta_y)
	var place := rng.randf_range(MIN_PLACE_FRAC, MAX_PLACE_FRAC)
	var air_gap := maxf(reach * place, 0.2)

	var length := rng.randf_range(MIN_BEAM_LENGTH, MAX_BEAM_LENGTH)
	var width := rng.randf_range(MIN_BEAM_WIDTH, MAX_BEAM_WIDTH)
	var half := length * 0.5

	# Center-to-center distance = previous half + air gap + this half, all measured
	# along the heading (the beam's long axis), so the empty span the player jumps
	# is exactly `air_gap` end-to-end.
	var center_gap := _prev_half + air_gap + half
	var new_xz := _prev_xz + _heading * center_gap
	var top_y := _prev_top_y + delta_y

	# yaw = heading angle aligns the beam's long axis with the path AND matches the
	# runtime's box standing test (which rotates the player offset by -yaw), so the
	# player registers as standing on the beam along its length.
	blocks.append({
		"index": i,
		"center": Vector3(new_xz.x, top_y, new_xz.y),
		"size": Vector2(length, width),
		"yaw": _heading.angle(),
		"radius": half,
		"shape": "box",
		"heading": _heading.angle(),
		"delta_y": delta_y,
		"air_gap": air_gap,
		"model_speed": s,
	})

	_prev_xz = new_xz
	_prev_top_y = top_y
	_prev_half = half
