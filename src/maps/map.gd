class_name Map extends Node

signal target_killed

@onready var player: Player = $Player
@onready var end_zone: Area3D = $EndZone
@onready var start_zone: Area3D = $StartZone
@onready var target_container: Node = $Targets
@onready var start_pos: Vector3 = player.global_position
@onready var start_rotation: Vector3 = player.global_rotation
@onready var player_container: Node = $Players
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
	Global.game_manager.player_switched_map.connect(_on_player_switched_map)
	Global.game_manager.player_diconnected.connect(_on_player_disconnected)
	Global.game_manager.player_left_map.connect(_on_player_disconnected)
	Global.game_manager.switched_map.rpc(Global.game_manager.current_map.mid)
	Global.game_manager.replay_requested.connect(_on_replay_requested)
	target_killed.connect(_on_target_killed)
	_on_target_killed()
	
	map_ui.slider.value_changed.connect(_on_replay_slider_changed)
	map_ui.slider.drag_started.connect(recorder.pause_playback)
	map_ui.slider.drag_ended.connect(func(changed: bool) -> void: recorder.resume_playback())
	
func _on_replay_slider_changed(value: float) -> void:
	recorder.current_frame = value

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

func _on_player_disconnected(pid: int) -> void:
	var p := find_player(pid)
	if p == null: return
	p.queue_free()

func _on_player_switched_map(pid: int, map: MapData) -> void:
	if Global.game_manager.current_map.mid != map.mid: return

	_received_switch.rpc_id(pid)
	if not player_exists(pid):
		spawn_player(pid)

@rpc("any_peer", "call_remote", "reliable")
func _received_switch() -> void:
	if not player_exists(multiplayer.get_remote_sender_id()):
		spawn_player(multiplayer.get_remote_sender_id())

func spawn_player(pid: int) -> void:
	var inst: Player = PlayerScene.instantiate()
	player_container.add_child(inst)
	inst.name = str(pid)
	inst.pid = pid
	inst.global_position = start_pos
	inst.set_name_label(Global.game_manager.get_player_name(pid))

func _physics_process(_delta: float) -> void:
	if running:
		recorder.add_frame(player.global_position, player.global_rotation.y)
		player.set_timer(timer)
		
	if recorder.is_playing():
		map_ui.set_frame(recorder.current_frame, len(recorder.currently_playing))
	
@rpc("any_peer", "call_remote", "unreliable")
func moved(pos: Vector3, y_rot: float) -> void:
	var p := find_player(multiplayer.get_remote_sender_id())
	if p == null: return

	p.global_position = pos
	p.global_rotation.y = y_rot

func find_player(pid: int) -> Player:
	var players := player_container.get_children()

	for p in players:
		if p is Player:
			var dp := p as Player 
			if dp.pid == pid:
				return dp

	return null

func get_players() -> Array[Player]:
	var ret: Array[Player]	
	ret.assign(player_container.get_children())
	return ret

func get_target_spawns() -> Array[Node3D]:
	var ret: Array[Node3D]
	ret.assign(target_spawns_container.get_children())
	return ret

func player_exists(pid: int) -> bool:
	return find_player(pid) != null

func _start_run() -> void:
	if currently_racing_steam_id != 0:
		recorder.play_bytes(race_recording_bytes, true)
	
	sound_player.stream = StartRunSound
	sound_player.play()
	running = true

func _on_player_jump() -> void:
	if not completed and not running:
		_start_run()

func _on_start_zone_exited(body: Node3D) -> void:
	if body is Player and not completed and not running:
		var p := body as Player
		if p.is_me():
			_start_run()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		restart()

	if not completed and _is_player_in_zone(end_zone) and target_container.get_child_count() == 0 and can_win:
		_win()
	
	if running:
		timer += delta

func _is_player_in_zone(zone: Area3D) -> bool:
	var bodies := zone.get_overlapping_bodies()

	for body in bodies:
		if body is Player:
			var p: Player = body
			if not p.is_me(): continue

			return true

	return false

func _win() -> void:
	completed = true
	running = false
	sound_player.stream = WinRunSound
	sound_player.play()

	var bytes := recorder.to_bytes()
	Global.server_bridge.publish_run(bytes, Global.game_manager.current_map.name, int(timer * 1000))
	player.show_end_run_stats(timer)

func spawn_target(pos: Vector3) -> void:
	var inst: Target = TargetScene.instantiate()
	target_container.add_child(inst)
	inst.global_position = pos

func restart() -> void:
	if player.sniper_overlay.visible:
		player.weapon_handler.toggle_sniper_scope()

	player.global_position = start_pos
	
	player.camera._input_rotation.y = -start_rotation.y
	player.camera._input_rotation.x = 0
	
	if recorder.ghost:
		recorder.ghost.visible = false
		
	player.velocity = Vector3.ZERO
	player.weapon_handler.set_weapon(null)

	can_win = false

	for node in get_tree().get_nodes_in_group("decal"):
		node.queue_free()

	for node in get_tree().get_nodes_in_group("weapon_pickup"):
		var wp: WeaponPickup = node
		wp.reset()

	for node in target_container.get_children():
		node.queue_free()

	for spawn in get_target_spawns():
		spawn_target(spawn.global_position)
	
	_on_target_killed()

	recorder.clear()
	completed = false
	running = false
	timer = 0.0
	player.set_timer(timer)
