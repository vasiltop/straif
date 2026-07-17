class_name EndlessBhop extends Node3D

# Runtime for the FIRST procedural, endless, seed-deterministic bhop map
# (map_reverie). The layout is a pure function of the run seed: the trajectory
# solver in EndlessGenerator places every block using an assumed model speed,
# so the same seed reproduces the exact same map for everyone. Score is the
# number of blocks traversed before falling (player performance, not derivable
# from the seed) and is submitted to the endless seed leaderboard.
#
# This intentionally does NOT reuse the time-trial flow from speedrun.gd: there
# is no EndZone / time win. Scoring is distance/blocks instead.

const MAP_NAME := "map_reverie"
const MODE := "bhop"

const BLOCK_THICKNESS := 1.0
const AHEAD := 32
const BEHIND := 8
const FALL_MARGIN := 6.0
# Player origin sits ~1.0u above the feet (capsule bottom); used to compare the
# origin against block tops when deciding what the player is standing on.
const FEET_OFFSET := 1.0

@onready var player: Player = $Player

var generator: EndlessGenerator
var run_seed: int
var block_nodes: Dictionary[int, Node3D] = {}
var current_index := 0
var running := false
var dead := false
var _has_jumped := false
var _last_top := 0.0

var start_pos: Vector3
var start_rot: Vector3

var mat_main: ShaderMaterial
var mat_accent: ShaderMaterial

# HUD nodes.
var blocks_label: Label
var seed_label: Label
var death_panel: PanelContainer
var final_label: Label
var lb_rows: VBoxContainer
var lb_status: Label

func _ready() -> void:
	Global.multiplayer.multiplayer_peer = null
	player.setup()
	player.hardcore = false
	player.jumped.connect(_on_player_jump)

	start_pos = player.global_position
	start_rot = player.global_rotation

	_build_materials()
	_build_hud()

	run_seed = _random_seed()
	_start_run(run_seed)

func _random_seed() -> int:
	return abs(int(Time.get_unix_time_from_system() * 1000.0)) ^ (randi() << 8)

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
	generator = EndlessGenerator.new(seed)

	for node in block_nodes.values():
		node.queue_free()
	block_nodes.clear()

	current_index = 0
	_last_top = 0.0
	dead = false
	running = false
	_has_jumped = false

	player.global_position = start_pos
	player.camera._input_rotation = start_rot
	player.velocity = Vector3.ZERO
	player.is_pre_capped = true
	player.can_move = true
	player.can_turn = true

	_update_stream()
	_hide_death_ui()
	_update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_player_jump() -> void:
	if not _has_jumped:
		_has_jumped = true
		player.is_pre_capped = false
		running = true

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_start_run(run_seed)
		return

	if dead:
		return

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

func _check_fall() -> void:
	if player.global_position.y < _last_top - FALL_MARGIN:
		_die()

func _die() -> void:
	if dead:
		return
	dead = true
	running = false
	player.can_move = false
	player.velocity = Vector3.ZERO
	_show_death_ui()
	_submit_score()

func _submit_score() -> void:
	if Global.server_bridge == null:
		return
	await Global.server_bridge.publish_endless_run(MAP_NAME, run_seed, current_index)

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
	seed_label = _make_label("Seed: 0", 16)
	info.add_child(seed_label)

	death_panel = PanelContainer.new()
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	death_panel.visible = false
	layer.add_child(death_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	death_panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(420, 0)
	margin.add_child(v)

	final_label = _make_label("You fell!", 26)
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(final_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)

	var retry_btn := Button.new()
	retry_btn.text = "Retry (same seed)"
	retry_btn.focus_mode = Control.FOCUS_NONE
	retry_btn.pressed.connect(func() -> void: _start_run(run_seed))
	buttons.add_child(retry_btn)

	var new_btn := Button.new()
	new_btn.text = "New seed"
	new_btn.focus_mode = Control.FOCUS_NONE
	new_btn.pressed.connect(func() -> void: _start_run(_random_seed()))
	buttons.add_child(new_btn)

	var lb_title := _make_label("Seed leaderboard (click to load)", 18)
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
	if seed_label != null:
		seed_label.text = "Seed: %d" % run_seed

func _show_death_ui() -> void:
	final_label.text = "You fell!  Blocks: %d" % current_index
	death_panel.visible = true
	player.can_turn = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_leaderboard()

func _hide_death_ui() -> void:
	if death_panel != null:
		death_panel.visible = false

func _refresh_leaderboard() -> void:
	for child in lb_rows.get_children():
		child.queue_free()
	lb_status.text = "Loading..."

	if Global.server_bridge == null:
		lb_status.text = "Leaderboard unavailable."
		return

	var entries: Array = await Global.server_bridge.fetch_endless_leaderboard(MAP_NAME)
	if entries == null or entries.is_empty():
		lb_status.text = "No runs yet. Be the first!"
		return

	lb_status.text = ""
	var rank := 1
	for entry in entries:
		var e: ServerBridge.EndlessEntry = entry
		var row := Button.new()
		row.text = "%d. %s — %d blocks (seed %d)" % [rank, e.username, e.blocks_reached, e.seed]
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var loaded_seed := e.seed
		row.pressed.connect(func() -> void: _start_run(loaded_seed))
		lb_rows.add_child(row)
		rank += 1
