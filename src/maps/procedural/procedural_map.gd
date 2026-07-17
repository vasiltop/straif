class_name ProceduralMap extends Node3D

# Runtime for a procedural, endless map (used by map_reverie in the ENDLESS
# gamemode). The layout is streamed on the fly by a ProceduralGenerator pipeline
# selected via the `pipeline` export, so this runtime is generator-agnostic:
# swapping in a future pipeline needs no changes here. Every gap the active
# pipeline emits is clearable as long as the player keeps their speed up, and
# score is the number of blocks traversed in a run.
#
# Like the target-practice and movement-only modes, the game is always moving:
# there is no death screen. Falling instantly respawns the player at the start
# with a fresh layout and submits the run's distance. The seed is irrelevant to
# scoring — the leaderboard simply ranks how many blocks players can cover.
# Hold the leaderboard key (Tab) to view the global blocks leaderboard.

# Which registered generation pipeline this map streams (see ProceduralPipelines).
@export var pipeline := "endless"
# Leaderboard map name to use when no map is selected (headless tests). In game
# the name comes from the selected map so any future procedural map just works.
@export var fallback_map_name := "map_reverie"

const BLOCK_THICKNESS := 1.0
const AHEAD := 32
const BEHIND := 8
const FALL_MARGIN := 6.0
# Player origin sits ~1.0u above the feet (capsule bottom); used to compare the
# origin against block tops when deciding what the player is standing on.
const FEET_OFFSET := 1.0

@onready var player: Player = $Player

var generator: ProceduralGenerator
var run_seed: int
var block_nodes: Dictionary[int, Node3D] = {}
var current_index := 0
var session_best := 0
var running := false
var _has_jumped := false
var _last_top := 0.0
var _submitted_best := 0

var start_pos: Vector3
var start_rot: Vector3

var mat_main: ShaderMaterial
var mat_accent: ShaderMaterial

# HUD nodes.
var blocks_label: Label
var best_label: Label
var lb_panel: PanelContainer
var lb_rows: VBoxContainer
var lb_status: Label
var _lb_loading := false

func _ready() -> void:
	Global.multiplayer.multiplayer_peer = null
	player.setup()
	player.hardcore = false
	player.jumped.connect(_on_player_jump)

	start_pos = player.global_position
	start_rot = player.global_rotation

	_build_materials()
	_build_hud()

	_start_run(_random_seed())

func _random_seed() -> int:
	return abs(int(Time.get_unix_time_from_system() * 1000.0)) ^ (randi() << 8)

# Leaderboard map name: the selected map in game, or the fallback for headless.
func _map_name() -> String:
	if Global.game_manager != null and Global.game_manager.current_map != null:
		return Global.game_manager.current_map.name
	return fallback_map_name

func _build_materials() -> void:
	var shader: Shader = load("res://src/maps/tiles/building.gdshader")
	var purple: Texture2D = load("res://src/textures/greybox_texture/greybox_purple_solid.png")
	var light: Texture2D = load("res://src/textures/greybox_texture/greybox_light_solid.png")
	var blue: Texture2D = load("res://src/textures/greybox_texture/greybox_blue_solid.png")

	mat_main = ShaderMaterial.new()
	mat_main.shader = shader
	mat_main.set_shader_parameter("texture_wall", purple)
	mat_main.set_shader_parameter("texture_roof", light)
	mat_main.set_shader_parameter("wall_texture_scale", 0.34)
	mat_main.set_shader_parameter("roof_texture_scale", 0.45)

	mat_accent = ShaderMaterial.new()
	mat_accent.shader = shader
	mat_accent.set_shader_parameter("texture_wall", blue)
	mat_accent.set_shader_parameter("texture_roof", light)
	mat_accent.set_shader_parameter("wall_texture_scale", 0.34)
	mat_accent.set_shader_parameter("roof_texture_scale", 0.45)

# --- Run lifecycle -------------------------------------------------------

func _start_run(seed: int) -> void:
	run_seed = seed
	generator = ProceduralPipelines.create(pipeline, seed)

	for node in block_nodes.values():
		node.queue_free()
	block_nodes.clear()

	current_index = 0
	_last_top = 0.0
	running = false
	_has_jumped = false

	player.global_position = start_pos
	player.camera._input_rotation = start_rot
	player.velocity = Vector3.ZERO
	player.is_pre_capped = true
	player.can_move = true
	player.can_turn = true

	_update_stream()
	_update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_player_jump() -> void:
	if not _has_jumped:
		_has_jumped = true
		player.is_pre_capped = false
		running = true

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_start_run(_random_seed())
		return

	_handle_leaderboard_input()

	_update_stream()
	_update_progress()
	_check_fall()
	_update_hud()

func _update_stream() -> void:
	if generator == null:
		return
	generator.ensure(current_index + AHEAD + 1)
	var lo := maxi(0, current_index - BEHIND)
	var hi := current_index + AHEAD

	for idx in range(lo, hi + 1):
		if not block_nodes.has(idx):
			var node := _make_block(generator.get_block(idx))
			add_child(node)
			block_nodes[idx] = node

	for idx in block_nodes.keys():
		if idx < lo or idx > hi:
			block_nodes[idx].queue_free()
			block_nodes.erase(idx)

func _make_block(spec: Dictionary) -> Node3D:
	var center: Vector3 = spec.center
	var size: Vector2 = spec.size
	var idx: int = spec.index

	var body := StaticBody3D.new()
	var box_size := Vector3(size.x, BLOCK_THICKNESS, size.y)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.material_override = mat_accent if (idx % 4 == 0) else mat_main
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	body.add_child(col)

	body.position = Vector3(center.x, center.y - BLOCK_THICKNESS * 0.5, center.z)
	return body

func _update_progress() -> void:
	var best := -1
	var start := maxi(0, current_index - 2)
	for idx in range(start, current_index + AHEAD):
		var spec := generator.get_block(idx)
		var c: Vector3 = spec.center
		var s: Vector2 = spec.size
		var dx: float = absf(player.global_position.x - c.x)
		var dz: float = absf(player.global_position.z - c.z)
		if dx <= s.x * 0.5 + 0.5 and dz <= s.y * 0.5 + 0.5:
			var feet_y := player.global_position.y - FEET_OFFSET
			if absf(feet_y - c.y) < 0.6:
				best = maxi(best, idx)
				_last_top = c.y
	if best >= 0:
		current_index = maxi(current_index, best + 1)
		session_best = maxi(session_best, current_index)

func _check_fall() -> void:
	if player.global_position.y < _last_top - FALL_MARGIN:
		_on_fall()

# On falling we never stop the game: record and submit the distance, then
# immediately respawn with a fresh layout so the player keeps moving.
func _on_fall() -> void:
	_submit_score(current_index)
	_start_run(_random_seed())

func _submit_score(blocks: int) -> void:
	if blocks <= 0 or blocks <= _submitted_best:
		return
	_submitted_best = blocks
	if Global.server_bridge == null:
		return
	await Global.server_bridge.publish_endless_run(_map_name(), blocks)

# --- HUD -----------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var info := VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	info.position = Vector2(24, 24)
	layer.add_child(info)

	blocks_label = _make_label("Blocks: 0", 28)
	info.add_child(blocks_label)
	best_label = _make_label("Best: 0", 16)
	info.add_child(best_label)
	var hint := _make_label("Hold %s for leaderboard" % Global.settings_manager.get_keybind_string("leaderboard"), 14)
	info.add_child(hint)

	lb_panel = PanelContainer.new()
	lb_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lb_panel.position = Vector2(0, 60)
	lb_panel.visible = false
	layer.add_child(lb_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	lb_panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(420, 0)
	margin.add_child(v)

	var lb_title := _make_label("Endless — Most Blocks", 22)
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lb_title)

	lb_status = _make_label("", 14)
	lb_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lb_status)

	lb_rows = VBoxContainer.new()
	lb_rows.add_theme_constant_override("separation", 4)
	v.add_child(lb_rows)

func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label

func _update_hud() -> void:
	if blocks_label != null:
		blocks_label.text = "Blocks: %d" % current_index
	if best_label != null:
		best_label.text = "Best: %d" % session_best

# --- Leaderboard (hold Tab) ---------------------------------------------

func _handle_leaderboard_input() -> void:
	if player.pause_menu.visible:
		return
	if Input.is_action_just_pressed("leaderboard"):
		lb_panel.visible = true
		_refresh_leaderboard()
	elif Input.is_action_just_released("leaderboard"):
		lb_panel.visible = false

func _refresh_leaderboard() -> void:
	if _lb_loading:
		return
	_lb_loading = true
	for child in lb_rows.get_children():
		child.queue_free()
	lb_status.text = "Loading..."

	if Global.server_bridge == null:
		lb_status.text = "Leaderboard unavailable."
		_lb_loading = false
		return

	var entries: Array = await Global.server_bridge.fetch_endless_leaderboard(_map_name())
	_lb_loading = false
	if not is_instance_valid(lb_panel) or not lb_panel.visible:
		return
	if entries == null or entries.is_empty():
		lb_status.text = "No runs yet. Be the first!"
		return

	lb_status.text = ""
	for entry in entries:
		var e: ServerBridge.EndlessEntry = entry
		var row := _make_label("%d. %s — %d blocks" % [e.position, e.username, e.blocks_reached], 16)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lb_rows.add_child(row)
