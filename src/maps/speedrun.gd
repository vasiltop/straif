class_name Map extends Node

signal target_killed

@onready var player: Player = $Player
@onready var end_zone: Area3D = $EndZone
@onready var start_zone: Area3D = $StartZone
@onready var target_container: Node = $Targets
@onready var start_pos: Vector3 = player.global_position
@onready var start_rotation: Vector3 = player.global_rotation
@onready var target_spawns_container: Node = $TargetSpawns
@onready var sound_player := AudioStreamPlayer.new()
@onready var recorder := Recorder.new(player.camera, self)
@onready var map_ui: MapUi = MapUiScene.instantiate()

const PlayerScene := preload("res://src/player/player.tscn")
const TargetScene := preload("res://src/target/target.tscn")
const StartRunSound = preload("res://src/sounds/run.wav")
const WinRunSound = preload("res://src/sounds/win.wav")
const MapUiScene = preload("res://src/maps/map_ui.tscn")
const START_ZONE_TIMER := 1.5

var timer := 0.0
var start_timer := 0.0
var completed: bool = false
var running: bool = false
var currently_racing_steam_id: int
var race_recording_bytes: PackedByteArray
var player_in_end_zone: bool
var _has_jumped: bool
var dragging_frame_slider: bool

func _ready() -> void:
	Global.multiplayer.multiplayer_peer = null
	player.setup()
	add_child(recorder)
	add_child(sound_player)
	add_child(map_ui)
	player.weapon_handler.shot.connect(map_ui.on_shot)
	player.toggled_pause.connect(_on_toggled_pause)
	player.hardcore = false
	
	map_ui.return_control_to_player.connect(_on_return_control_to_player)
	map_ui.set_replay_visible(false)
	player.jumped.connect(_on_player_jump)
	Global.game_manager.replay_requested.connect(_on_replay_requested)
	target_killed.connect(_on_target_killed)
	_on_target_killed()
	
	start_zone.body_exited.connect(
		func(body):
			if not running and not completed:
				_start_run()
	)

	map_ui.replay_slider.value_changed.connect(_on_replay_slider_changed)
	map_ui.replay_slider.drag_started.connect(
		func() -> void:
			recorder.pause_playback()
			dragging_frame_slider = true
			)
	map_ui.replay_slider.drag_ended.connect(
		func(changed: bool) -> void:
			recorder.resume_playback()
			dragging_frame_slider = false
			)

	end_zone.body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player and body.is_me():
				player_in_end_zone = true
	)

	end_zone.body_exited.connect(
		func(body: Node3D) -> void:
			if body is Player and body.is_me():
				player_in_end_zone = false
	)
	
	restart(player)

func _on_toggled_pause(value: bool) -> void:
	map_ui.set_replay_visible(false)
	map_ui.leaderboard.middle.visible = false
	_on_return_control_to_player()

func _on_replay_slider_changed(value: float) -> void:
	recorder.set_frame(value)

func is_watching_replay() -> bool:
	return map_ui.is_replay_visible()

func _on_return_control_to_player(should_restart := true) -> void:
	map_ui.set_replay_visible(false)
	player.camera.current = true
	player.gun_camera.current = true
	recorder.controller.camera.current = false
	recorder.controller.gun_camera.current = false
	recorder.controller.ui.visible = false
	player.ui.visible = true
	player.can_move = true
	player.weapon_handler.visible = true
	recorder.pause_playback()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if should_restart:
		restart(player)

func _on_target_killed() -> void:
	map_ui.set_target_status(target_container.get_child_count(), target_spawns_container.get_child_count())

func _on_replay_requested(data: String) -> void:
	race_recording_bytes.clear()
	currently_racing_steam_id = 0
	
	restart(recorder.controller)
	map_ui.set_replay_visible(true)
	player.camera.current = false
	player.gun_camera.current = false
	player.can_move = false
	player.weapon_handler.visible = false
	player.ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	recorder.play_bytes(Marshalls.base64_to_raw(data))
	map_ui.set_frame(recorder.current_frame, len(recorder.currently_playing))

func requires_unlock() -> bool:
	return map_ui.requires_unlock()

func combined_requires_unlock() -> bool:
	return requires_unlock() or player.requires_unlock()

func _physics_process(_delta: float) -> void:
	if running:
		map_ui.set_timer(timer)
		_recorder_process()

	if recorder.is_playing():
		map_ui.set_frame(recorder.current_frame, len(recorder.currently_playing))

func _recorder_process() -> void:
	var ads_input := Input.is_action_just_pressed("scope")
	var reload_input := Input.is_action_just_pressed("reload")
	var shoot_input := player.weapon_handler.attack_input() and player.weapon_handler.mag_ammo > 0
	var rot_y := player.global_rotation.y
	var rot_x := player.camera.global_rotation.x
	var rot := Vector2(rot_x, rot_y)
	
	var left_input := Input.is_action_pressed("left")
	var right_input := Input.is_action_pressed("right")
	var up_input := Input.is_action_pressed("up")
	var down_input := Input.is_action_pressed("down")
	
	var targets := target_container.get_children()
	var targets_state: Array[bool]
	targets_state.resize(len(get_target_spawns()))
	for target in targets:
		targets_state[target.identifier] = true
	
	var frame: Recorder.Frame = Recorder.Frame.new()

	frame.rot = rot
	frame.position = player.global_position
	frame.shoot_input = shoot_input
	frame.ads_input = ads_input
	frame.reload_input = reload_input
	frame.weapon_index = Global.game_manager.get_weapon_index(player.weapon_handler.current_weapon)
	frame.back_input = down_input
	frame.forward_input = up_input
	frame.right_input = right_input
	frame.left_input = left_input
	frame.ammo = player.weapon_handler.mag_ammo
	frame.targets_state = targets_state

	recorder.add_frame(frame)

func get_target_spawns() -> Array[Node3D]:
	var ret: Array[Node3D]
	ret.assign(target_spawns_container.get_children())
	return ret

func _start_run() -> void:
	if currently_racing_steam_id != 0:
		recorder.play_bytes(race_recording_bytes, true)
	
	recorder.clear()
	sound_player.stream = StartRunSound
	sound_player.play()
	running = true
	end_zone.monitoring = true
	player.can_move = true

func _on_player_jump() -> void:
	if not _has_jumped:
		player.is_pre_capped = false
		if not running and not completed:
			_start_run()
		_has_jumped = true
		map_ui.first_jump_speed_label.visible = map_ui.alt_speed_label.visible
		map_ui.first_jump_speed_label.text = map_ui.speed_label.text

func _process(delta: float) -> void:
	if map_ui.is_replay_visible(): return
	
	if not completed and player_in_end_zone and target_container.get_child_count() == 0:
		await _win()

	if Input.is_action_just_pressed("restart"):
		restart(player)

	if running:
		timer += delta

func _win() -> void:
	completed = true
	running = false
	sound_player.stream = WinRunSound
	sound_player.play()
	
	var bytes := recorder.to_bytes()
	await Global.server_bridge.publish_run(Global.game_manager.current_mode, bytes, Global.game_manager.current_map.name, int(timer * 1000))

func spawn_target(identifier: int, pos: Vector3) -> void:
	var inst: Target = TargetScene.instantiate()
	target_container.add_child(inst)
	inst.global_position = pos
	inst.identifier = identifier

func restart(player: Player) -> void:
	recorder.pause_playback()
	recorder.controller.visible = false
	#player.can_move = false
	
	if player.sniper_overlay.visible:
		player.weapon_handler.toggle_sniper_scope()

	player.global_position = start_pos
	player.camera._input_rotation = start_rotation
	player_in_end_zone = false
	player.weapon_handler.shot.emit(0, 0)
	player.is_pre_capped = true

	player.velocity = Vector3.ZERO
	player.weapon_handler.set_weapon(null)
	
	var mode := Global.game_manager.current_mode
	
	for node in get_tree().get_nodes_in_group("decal"):
		node.queue_free()

	reset_weapon_pickups()
	reset_targets()

	completed = false
	running = false
	timer = 0.0
	map_ui.set_timer(timer)
	end_zone.monitoring = false
	_has_jumped = false
	map_ui.first_jump_speed_label.visible = false
	
	start_timer = START_ZONE_TIMER

func reset_weapon_pickups() -> void:
	var mode := Global.game_manager.current_mode
	
	for node in get_tree().get_nodes_in_group("weapon_pickup"):
		var wp: WeaponPickup = node
		if mode == "target":
			wp.reset()
		else:
			wp.deactivate()

func reset_targets() -> void:
	var mode := Global.game_manager.current_mode
	
	for node in target_container.get_children():
		node.queue_free()

	if mode == "target":
		var target_spawns := get_target_spawns()
		for i in range(len(target_spawns)):
			spawn_target(int(target_spawns[i].name), target_spawns[i].global_position)
	
	_on_target_killed()
