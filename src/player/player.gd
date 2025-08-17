class_name Player extends CharacterBody3D

signal jumped

@onready var camera: PlayerCamera = $Eye/Camera
@onready var gun_camera: Camera3D = $Eye/Camera/GunVPContainer/GunVP/GunCam
@onready var gun_vp: SubViewport = $Eye/Camera/GunVPContainer/GunVP
@onready var timer_label: Label = $UI/UiContainer/BottomLeft/V/Timer
@onready var target_label: Label = $UI/UiContainer/BottomLeft/V/EnemiesLeft
@onready var ui: CanvasLayer = $UI
@onready var name_label: Label3D = $Name
@onready var weapon_handler: WeaponHandler = $Eye/Camera/WeaponHandler
@onready var camera_anchor: Marker3D = $CameraAnchor
@onready var leaderboard: Leaderboard = $UI/UiContainer/GameInfo/Leaderboard
@onready var speed_label: Label = $UI/UiContainer/BottomLeft/V/Speed
@onready var alt_speed_label: Label = $UI/UiContainer/Middle/Speed
@onready var sniper_overlay: TextureRect = $UI/UiContainer/SniperOverlay
@onready var raycast: RayCast3D = $Eye/Camera/RayCast

const RunSound := preload("res://src/sounds/run.mp3")
const MAX_G_SPEED := 5.5
const MAX_G_ACCEL := MAX_G_SPEED * 8
const MAX_A_SPEED := 0.7
const MAX_A_ACCEL: float = 200
const MAX_SLOPE: float = 1
const JUMP_FORCE: float = 4

var gravity: float = 12
var pid: int
var map: Map
var _run_audio_player := AudioStreamPlayer.new()

func is_me() -> bool:
	return multiplayer.get_unique_id() == pid

func set_name_label(value: String) -> void:
	name_label.text = value

func show_end_run_stats(time: float) -> void:
	var is_pb: bool = Lobby.map_name_to_time[Lobby.current_map.name] > time
	var text := "Run completed in %ss%s" % [str(snapped(time, 0.01)), ", new PB!\nPress TAB to view your ranking." if is_pb else ""]
	
	Info.alert(text)

	if is_pb:
		Lobby.map_name_to_time[Lobby.current_map.name] = time

func setup(map: Map) -> void:
	camera.make_current()
	gun_camera.make_current()
	ui.visible = true
	pid = multiplayer.get_unique_id()
	self.map = map
	
	weapon_handler.visible = true
	weapon_handler.add_child(weapon_handler.hit_sound)
	add_child(_run_audio_player)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

	(get_node("HeadMesh") as Node3D).visible = false
	(get_node("BodyMesh") as Node3D).visible = false
	name_label.visible = false

func _on_viewport_resized() ->  void:
	var window_size := get_viewport().get_visible_rect().size
	gun_vp.size = window_size

func _ready() -> void:
	camera.current = false
	gun_camera.current = false
	ui.visible = false
	weapon_handler.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta: float) -> void:
	if not is_me(): return

	if Input.is_action_just_pressed("main_menu"):
		Lobby.switched_map.rpc(-1)
		get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	(get_node("UI/UiContainer/TopLeft/Fps") as Label).text = str(Engine.get_frames_per_second()) + " fps"

func _physics_process(delta: float) -> void:
	if not is_me(): return

	var map: Map = get_parent()
	for member in map.get_players():
		map.moved.rpc_id(member.pid, global_position, global_rotation.y)
	
	_movement_process(delta)
	
	var current_vel := velocity
	current_vel.y = 0
	speed_label.text = "%.2fu/s" % current_vel.length()
	alt_speed_label.text = speed_label.text
	alt_speed_label.visible = Settings.value("Display", "speed")

func set_timer(value: float) -> void:
	timer_label.text = "Time: %.3fs" % value

func set_target_status(left: int, total: int) -> void:
	target_label.text = "Targets: %d/%d" % [left, total]

func _movement_process(delta: float) -> void:
	if map.is_watching_replay(): return
	
	var wish_dir := Input.get_vector("left", "right", "up", "down")
	wish_dir = wish_dir.rotated(-rotation.y)

	var vel_planar := Vector2(velocity.x, velocity.z)
	var vel_vertical := _apply_gravity(velocity.y, delta)
	vel_planar = _apply_friction(vel_planar, delta, wish_dir)
	vel_planar = _update_velocity_ground(vel_planar, wish_dir, delta)
	vel_vertical = _check_for_jump(vel_vertical)

	velocity = Vector3(vel_planar.x, vel_vertical, vel_planar.y)
	
	if velocity.length() > 0 and not _run_audio_player.playing and grounded():
		_run_audio_player.stream = RunSound
		_run_audio_player.play()

	move_and_slide()

func _apply_gravity(velocity_y: float, delta: float) -> float:
	if grounded(): return velocity_y
	return velocity_y - gravity * delta

func grounded() -> bool:
	return test_move(global_transform, Vector3(0, -0.01, 0))

func _apply_friction(vel_planar: Vector2, delta: float, wish_dir: Vector2) -> Vector2:
	if not grounded(): return vel_planar
	if Input.is_action_pressed("jump"): return vel_planar
	
	var v: Vector2 = vel_planar - vel_planar.normalized() * delta * MAX_G_ACCEL / 2

	if v.length_squared() < 1.0 and wish_dir.length_squared() < 0.01:
		return Vector2.ZERO
	else:
		return v

func _update_velocity_ground(vel_planar: Vector2, wish_dir: Vector2, delta: float) -> Vector2:
	var current_speed := vel_planar.dot(wish_dir)
	var max_speed := MAX_G_SPEED if grounded() else MAX_A_SPEED
	var max_accel := MAX_G_ACCEL if grounded() else MAX_A_ACCEL
	var add_speed: float = clamp(max_speed - current_speed, 0.0, max_accel * delta)
	return vel_planar + wish_dir * add_speed

func _check_for_jump(vel_vertical: float) -> float:
	var jump_input := Input.is_action_pressed("jump") or Input.is_action_just_pressed("jump")

	if jump_input and grounded():
		jumped.emit()
		return JUMP_FORCE

	return vel_vertical
