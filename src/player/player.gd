class_name Player extends CharacterBody3D

signal jumped

@onready var camera: PlayerCamera = $Eye/Camera
@onready var gun_camera: Camera3D = $Eye/Camera/GunVPContainer/GunVP/GunCam
@onready var gun_vp: SubViewport = $Eye/Camera/GunVPContainer/GunVP
@onready var name_label: Label3D = $Name
@onready var weapon_handler: WeaponHandler = $Eye/Camera/WeaponHandler
@onready var camera_anchor: Marker3D = $CameraAnchor
@onready var sniper_overlay: TextureRect = $UI/SniperOverlay
@onready var third_person: Node3D = $ThirdPerson

const RunSound := preload("res://src/sounds/run.mp3")
const MAX_G_SPEED := 5.5
const MAX_G_ACCEL := MAX_G_SPEED * 8
const MAX_A_SPEED := 0.7
const MAX_A_ACCEL: float = 200
const MAX_SLOPE: float = 1
const JUMP_FORCE: float = 4
const RUN_SOUND_DELAY := 0.4

var _time_since_last_run_sound := RUN_SOUND_DELAY
var gravity: float = 12
var pid: int
var _run_audio_player := AudioStreamPlayer.new()
var can_move := true
var can_turn := true

func is_me() -> bool:
	return multiplayer.get_unique_id() == pid

func set_name_label(value: String) -> void:
	name_label.text = value

# This only gets called on the player we are controlling
func setup() -> void:
	camera.make_current()
	gun_camera.make_current()
	pid = multiplayer.get_unique_id()
	weapon_handler.visible = true
	weapon_handler.add_child(weapon_handler.hit_sound)
	add_child(_run_audio_player)
	third_person.visible = false
	name_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_viewport_resized() ->  void:
	var window_size := get_viewport().get_visible_rect().size
	gun_vp.size = window_size

func _ready() -> void:
	camera.current = false
	gun_camera.current = false
	weapon_handler.visible = false
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

func _process(delta: float) -> void:
	if not is_me(): return

	if Input.is_action_just_pressed("main_menu"):
		Global.multiplayer.multiplayer_peer = null
		get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_time_since_last_run_sound += delta

func _physics_process(delta: float) -> void:
	if not is_me(): return
	
	var jump_input := Input.is_action_pressed("jump") or Input.is_action_just_pressed("jump")
	_movement_process(delta, wish_dir(), jump_input)

	_update_state.rpc(global_position, global_rotation.y, camera.global_rotation.x, get_ups())

@rpc("any_peer", "call_remote", "unreliable")
func _update_state(pos: Vector3, rot_y: float, rot_x: float, speed: float) -> void:
	global_position = pos
	camera._input_rotation.y = rot_y
	camera._input_rotation.x = rot_x
	
	set_animation_blend(1.0 if speed >= 3.0 else 0.0)
		
func set_animation_blend(value: float) -> void:
	var anim_tree: AnimationTree = get_node("ThirdPerson/AnimationTree")
	anim_tree.set("parameters/blend/blend_amount", value)
	
func get_ups() -> float:
	var current_vel := velocity
	current_vel.y = 0.0
	return current_vel.length()

func wish_dir_from(left: bool, right: bool, up: bool, down: bool) -> Vector2:
	var wish_dir = Vector2(float(right) - float(left), float(down) - float(up))
	wish_dir = wish_dir.normalized()
	
	return wish_dir

func wish_dir() -> Vector2:
	var left_input := Input.is_action_pressed("left")
	var right_input := Input.is_action_pressed("right")
	var up_input := Input.is_action_pressed("up")
	var down_input := Input.is_action_pressed("down")
	return wish_dir_from(left_input, right_input, up_input, down_input)

func _movement_process(delta: float, wish_dir: Vector2, jump_input: bool) -> void:
	if not can_move: return
	
	wish_dir = wish_dir.rotated(-rotation.y)

	var vel_planar := Vector2(velocity.x, velocity.z)
	var vel_vertical := _apply_gravity(velocity.y, delta)
	vel_planar = _apply_friction(vel_planar, delta, wish_dir)
	vel_planar = _update_velocity_ground(vel_planar, wish_dir, delta)
	vel_vertical = _check_for_jump(vel_vertical, jump_input)

	velocity = Vector3(vel_planar.x, vel_vertical, vel_planar.y)
	
	if velocity.length() > 0 and _time_since_last_run_sound >= RUN_SOUND_DELAY and grounded():
		_run_audio_player.stream = RunSound
		_run_audio_player.pitch_scale = randf_range(0.95, 1.05)
		_run_audio_player.play()
		_time_since_last_run_sound = 0

	move_and_slide()

func _apply_gravity(velocity_y: float, delta: float) -> float:
	if grounded(): return velocity_y
	return velocity_y - gravity * delta

func grounded() -> bool:
	return is_on_floor()
	#return test_move(global_transform, Vector3(0, -0.01, 0))

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

func _check_for_jump(vel_vertical: float, jump_input: bool) -> float:
	if jump_input and grounded():
		jumped.emit()
		return JUMP_FORCE

	return vel_vertical
