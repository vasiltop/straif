class_name ProceduralGenerator extends RefCounted

# Base interface for a procedural, seed-deterministic block pipeline.
#
# A pipeline emits a forward-moving course of blocks as a pure function of its
# seed, so the same seed always reproduces the same layout. The runtime
# (ProceduralMap) talks only to this interface — it never knows which concrete
# pipeline it is streaming — so new generation pipelines can be added without
# touching the runtime or the map scene beyond a one-line `pipeline` selector.
#
# A block is a Dictionary with at least:
#   index: int          - 0-based position in the course
#   center: Vector3     - center of the block TOP surface (world space)
#   size: Vector2       - top footprint (x = width, y = depth)
# Optional object-variety fields honored by ProceduralMap:
#   shape: "box" (default) or "cylinder"
#   yaw:   float rotation around Y (radians), e.g. to align a beam to the path
#   radius: float       - footprint radius (used for cylinders / gap math)
# Pipelines may attach further fields (delta_y, model_speed, ...) for their own
# use and for tests.

var seed_value: int
var rng := RandomNumberGenerator.new()
var blocks: Array[Dictionary] = []

func _init(run_seed: int) -> void:
	seed_value = run_seed
	reset()

# Restart deterministically from the seed. Subclasses that keep their own
# cursors should override and call super() first.
func reset() -> void:
	rng.seed = seed_value
	blocks.clear()

# Ensure at least `count` blocks have been generated. Sequential and
# deterministic: an already-generated block is never regenerated.
func ensure(count: int) -> void:
	while blocks.size() < count:
		_generate_next()

func get_block(index: int) -> Dictionary:
	ensure(index + 1)
	return blocks[index]

# Append exactly one block to `blocks`. Must be overridden by a pipeline.
func _generate_next() -> void:
	push_error("ProceduralGenerator._generate_next() must be overridden")
