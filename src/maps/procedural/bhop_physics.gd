class_name BhopPhysics extends RefCounted

# Shared bhop jump kinematics, mirrored from src/player/player.gd. Every
# procedural pipeline reuses these so the makeable-gap math is identical across
# maps. Pipeline-specific tuning (model-speed floor/ramp, turn caps, step
# limits) stays in each generator so difficulty can vary per map.
const JUMP_FORCE := 4.0
const GRAVITY := 12.0

# Peak rise of a jump: JUMP_FORCE^2 / (2 * GRAVITY) = 0.667u. Up-steps must stay
# below this so the player clears them on the way down.
const JUMP_PEAK_RISE := JUMP_FORCE * JUMP_FORCE / (2.0 * GRAVITY)

# Airtime to land on a top that is delta_y above the launch top.
# Solves 4t - 6t^2 = delta_y for the later positive root.
static func hop_time(delta_y: float) -> float:
	var disc := JUMP_FORCE * JUMP_FORCE - 2.0 * GRAVITY * delta_y
	if disc < 0.0:
		disc = 0.0
	return (JUMP_FORCE + sqrt(disc)) / GRAVITY

# Maximum horizontal reach at planar speed s for a step of delta_y.
static func max_reach(s: float, delta_y: float) -> float:
	return s * hop_time(delta_y)

# Effective footprint radius of a near-square block along the path. Used
# identically by generators, placement math, and self-tests so edge-to-edge air
# gaps stay exact.
static func block_radius(size: Vector2) -> float:
	return (size.x + size.y) * 0.25
