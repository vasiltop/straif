class_name ProceduralPipelines extends RefCounted

# Registry of procedural map-generation pipelines. To add a new pipeline, write
# a ProceduralGenerator subclass and register it here under a short name; a map
# scene then selects it via ProceduralMap's `pipeline` export. Nothing in the
# runtime hardcodes a specific generator.

const PIPELINES := {
	"endless": preload("res://src/maps/procedural/endless_generator.gd"),
}

const DEFAULT_PIPELINE := "endless"

static func create(pipeline: String, seed: int) -> ProceduralGenerator:
	var script: Script = PIPELINES.get(pipeline)
	if script == null:
		push_error("Unknown procedural pipeline '%s', falling back to '%s'" % [pipeline, DEFAULT_PIPELINE])
		script = PIPELINES[DEFAULT_PIPELINE]
	return script.new(seed)

static func has(pipeline: String) -> bool:
	return PIPELINES.has(pipeline)
