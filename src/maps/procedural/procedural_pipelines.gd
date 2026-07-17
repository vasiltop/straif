class_name ProceduralPipelines extends RefCounted

# Auto-discovering registry of procedural map-generation pipelines.
#
# Every generator under res://src/maps/procedural/pipelines/ that extends
# ProceduralGenerator and declares `const PIPELINE_NAME := "..."` is registered
# automatically. To add a new pipeline you only drop a file in that folder — no
# edits here, in the runtime, or in any shared registry, which keeps stacked
# maps free of merge conflicts.

const PIPELINES_DIR := "res://src/maps/procedural/pipelines"
const DEFAULT_PIPELINE := "endless"

static var _cache: Dictionary = {}

static func _registry() -> Dictionary:
	if not _cache.is_empty():
		return _cache

	var dir := DirAccess.open(PIPELINES_DIR)
	if dir == null:
		push_error("Cannot open procedural pipelines dir: %s" % PIPELINES_DIR)
		return _cache

	for file in dir.get_files():
		# Exported/imported scripts can appear as .gd.remap in release builds.
		var script_name := file
		if script_name.ends_with(".remap"):
			script_name = script_name.trim_suffix(".remap")
		if not script_name.ends_with(".gd"):
			continue

		var script: Script = load("%s/%s" % [PIPELINES_DIR, script_name])
		if script == null:
			continue
		var consts := script.get_script_constant_map()
		if not consts.has("PIPELINE_NAME"):
			continue
		_cache[consts["PIPELINE_NAME"]] = script

	return _cache

static func create(pipeline: String, seed: int) -> ProceduralGenerator:
	var registry := _registry()
	var script: Script = registry.get(pipeline)
	if script == null:
		push_error("Unknown procedural pipeline '%s', falling back to '%s'" % [pipeline, DEFAULT_PIPELINE])
		script = registry.get(DEFAULT_PIPELINE)
	if script == null:
		push_error("No procedural pipelines registered")
		return null
	return script.new(seed)

static func has(pipeline: String) -> bool:
	return _registry().has(pipeline)

static func names() -> Array:
	return _registry().keys()
