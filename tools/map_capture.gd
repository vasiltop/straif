extends SceneTree

# Renders flattering screenshots of maps WITHOUT the gameplay Map script and
# WITHOUT the main menu overlay. Each map PackedScene is instantiated (its
# _ready does NOT run until added to a tree); we lift Level / Sun /
# WorldEnvironment into an isolated SubViewport (own World3D) so the autoloaded
# main menu, which draws on the root viewport, never appears in our capture.
#
# Enclosed maps use a "dollhouse" cutaway: named geometry (a ceiling or a wall)
# is hidden so an exterior camera can see the interior route.

const OUT_DIR := "res://images/screenshots/"
const SHOT_DIR := "res://tools/shots/"

# Per-map: hide = CSG node names to make invisible (cutaway);
# shots = [pos, look_at, fov]; first shot is the in-game preview.
var CONFIG := {
	"map_atrium": {
		"hide": ["CeilingPanel"],
		"shots": [
			{"pos": Vector3(15.0, 20.0, 13.0), "look": Vector3(-0.5, 0.5, -17.0), "fov": 50.0},
			{"pos": Vector3(-13.0, 16.0, -40.0), "look": Vector3(0.5, 0.8, -16.0), "fov": 55.0},
			{"pos": Vector3(1.0, 26.0, -12.0), "look": Vector3(-0.5, 0.5, -18.0), "fov": 56.0},
		],
	},
	"map_causeway": {
		"hide": [],
		"shots": [
			{"pos": Vector3(11.0, 10.5, -4.0), "look": Vector3(-1.5, -0.5, -34.0), "fov": 50.0},
			{"pos": Vector3(10.5, 4.0, 11.0), "look": Vector3(-1.0, 1.8, -44.0), "fov": 62.0},
			{"pos": Vector3(24.0, 5.5, -46.0), "look": Vector3(-2.0, 1.6, -55.0), "fov": 56.0},
		],
	},
	"map_reactor": {
		"hide": ["SouthWall"],
		"shots": [
			{"pos": Vector3(2.8, 9.0, 8.5), "look": Vector3(-0.3, 9.5, -1.5), "fov": 64.0},
			{"pos": Vector3(2.5, 2.6, 7.5), "look": Vector3(0.0, 14.0, -2.0), "fov": 70.0},
			{"pos": Vector3(0.5, 24.0, 6.0), "look": Vector3(0.0, 9.0, -0.5), "fov": 64.0},
		],
	},
}

func _init() -> void:
	call_deferred("_run", ["map_atrium", "map_causeway", "map_reactor"])

func _run(jobs: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	for map_name in jobs:
		await _capture_map(map_name)
	print("CAPTURE_DONE")
	quit()

func _hide_named(node: Node, names: Array) -> void:
	if node is CanvasItem or node is Node3D:
		if names.has(node.name):
			node.set("visible", false)
	for c in node.get_children():
		_hide_named(c, names)

func _capture_map(map_name: String) -> void:
	var path := "res://src/maps/speedrun/%s.tscn" % map_name
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Failed to load " + path)
		return
	var inst: Node = packed.instantiate()

	var cfg: Dictionary = CONFIG.get(map_name, {})
	var shots: Array = cfg.get("shots", [
		{"pos": Vector3(20, 15, 20), "look": Vector3(0, 2, -20), "fov": 55.0}
	])
	var hide: Array = cfg.get("hide", [])

	var sub := SubViewport.new()
	sub.size = Vector2i(1920, 1080)
	sub.own_world_3d = true
	sub.transparent_bg = false
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)

	for child_name in ["Level", "Sun", "WorldEnvironment"]:
		var n: Node = inst.get_node_or_null(child_name)
		if n:
			inst.remove_child(n)
			sub.add_child(n)

	if not hide.is_empty():
		_hide_named(sub, hide)

	var cam := Camera3D.new()
	sub.add_child(cam)
	cam.current = true

	for _i in range(28):
		await process_frame

	for i in range(shots.size()):
		var s: Dictionary = shots[i]
		cam.fov = float(s.get("fov", 55.0))
		cam.look_at_from_position(s["pos"], s["look"], Vector3.UP)
		cam.make_current()
		for _j in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var active := sub.get_camera_3d()
		print("CAM ", map_name, " shot", i, " pos=", cam.global_position, " active=", (active.global_position if active else Vector3.INF))
		var img := sub.get_texture().get_image()
		var out_path := (OUT_DIR + map_name + ".png") if i == 0 else (SHOT_DIR + map_name + "_angle" + str(i + 1) + ".png")
		img.save_png(ProjectSettings.globalize_path(out_path))
		print("SAVED ", out_path)

	sub.queue_free()
	inst.queue_free()
	await process_frame
