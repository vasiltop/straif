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
@onready var recorder := Recorder.new(player.camera)
@onready var map_ui: MapUi = MapUiScene.instantiate()

const PlayerScene := preload("res://src/player/player.tscn")
const TargetScene := preload("res://src/target/target.tscn")
const StartRunSound = preload("res://src/sounds/run.wav")
const WinRunSound = preload("res://src/sounds/win.wav")
const MapUiScene = preload("res://src/maps/map_ui.tscn")

var timer: float = 0.0
var completed: bool = false
var running: bool = false
var can_win: bool = false
var currently_racing_steam_id: int
var race_recording_bytes: PackedByteArray
var player_in_end_zone: bool
var _has_jumped: bool

func _ready() -> void:
	player.setup(self)
	restart()
	add_child(recorder)
	add_child(sound_player)
	add_child(map_ui)
	map_ui.return_control_to_player.connect(_on_return_control_to_player)
	map_ui.visible = false
	start_zone.body_exited.connect(_on_start_zone_exited)
	end_zone.body_entered.connect(func(_body: Node3D) -> void: can_win = true)
	player.jumped.connect(_on_player_jump)
	Global.game_manager.replay_requested.connect(_on_replay_requested)
	target_killed.connect(_on_target_killed)
	_on_target_killed()
	
	map_ui.slider.value_changed.connect(_on_replay_slider_changed)
	map_ui.slider.drag_started.connect(recorder.pause_playback)
	map_ui.slider.drag_ended.connect(func(changed: bool) -> void: recorder.resume_playback())
	
	end_zone.body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player:
				var p := body as Player
				if p.is_me():
					player_in_end_zone = true
	)

	end_zone.body_exited.connect(
		func(body: Node3D) -> void:
			if body is Player:
				var p := body as Player
				if p.is_me():
					player_in_end_zone = false
	)
	
func _on_replay_slider_changed(value: float) -> void:
	recorder.set_frame(value)

func is_watching_replay() -> bool:
	return map_ui.visible

func _on_return_control_to_player() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	map_ui.visible = false
	player.camera.make_current()
	player.camera.visible = true
	player.ui.visible = true
	restart()

func _on_target_killed() -> void:
	player.set_target_status(target_container.get_child_count(), target_spawns_container.get_child_count())

func _on_replay_requested(data: String) -> void:
	restart()
	map_ui.visible = true
	player.camera.visible = false
	player.ui.visible = false
	recorder.play_bytes(Marshalls.base64_to_raw(data))
	map_ui.set_frame(recorder.current_frame, len(recorder.currently_playing))
	
func _physics_process(_delta: float) -> void:
	if running:
		var frame := Recorder.FrameInfoV2.new(player.global_position, player.global_rotation.y, player.camera.global_rotation.x)
		recorder.add_frame(frame)
		player.set_timer(timer)
		
	if recorder.is_playing():
		map_ui.set_frame(recorder.current_frame, len(recorder.currently_playing))

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
	
func _show_pre_label() -> void:
	player.pre_strafe_speed.text = player.speed_label.text
	player.pre_strafe_speed.visible = Global.settings_manager.value("Display", "speed")

func _on_player_jump() -> void:
	if not completed and not running:
		_start_run()
		
	if not _has_jumped:
		_has_jumped = true
		_show_pre_label()

func _on_start_zone_exited(body: Node3D) -> void:
	if body is Player and not completed and not running:
		var p := body as Player
		if p.is_me():
			_start_run()

func _process(delta: float) -> void:
	if not completed and player_in_end_zone and target_container.get_child_count() == 0:
		await _win()

	if Input.is_action_just_pressed("restart"):
		restart()

	if running:
		timer += delta

func _win() -> void:
	completed = true
	running = false
	sound_player.stream = WinRunSound
	sound_player.play()

	var bytes := recorder.to_bytes()
	await Global.server_bridge.publish_run(Global.game_manager.current_mode, bytes, Global.game_manager.current_map.name, int(timer * 1000))

func spawn_target(pos: Vector3) -> void:
	var inst: Target = TargetScene.instantiate()
	target_container.add_child(inst)
	inst.global_position = pos

func restart() -> void:
	if player.sniper_overlay.visible:
		player.weapon_handler.toggle_sniper_scope()

	player.global_position = start_pos
	player_in_end_zone = false
	
	player.camera._input_rotation = start_rotation
	
	player.pre_strafe_speed.visible = false
	if recorder.ghost:
		recorder.ghost.visible = false
		
	player.velocity = Vector3.ZERO
	player.weapon_handler.set_weapon(null)

	can_win = false
	
	var mode := Global.game_manager.current_mode
	
	for node in get_tree().get_nodes_in_group("decal"):
		node.queue_free()

	for node in get_tree().get_nodes_in_group("weapon_pickup"):
		var wp: WeaponPickup = node
		if mode == "target":
			wp.reset()
		else:
			wp.deactivate()

	for node in target_container.get_children():
		node.queue_free()
	
	if mode == "target":
		for spawn in get_target_spawns():
			spawn_target(spawn.global_position)
	
	_on_target_killed()

	completed = false
	running = false
	timer = 0.0
	player.set_timer(timer)
	end_zone.monitoring = false
	_has_jumped = false
	
