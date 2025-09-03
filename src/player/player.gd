class_name Player extends CharacterBody3D

signal jumped
signal dead(sender: int, id: int)
signal damaged(health: float)
signal toggled_pause(value: bool)

@onready var camera: PlayerCamera = $Eye/Camera
@onready var gun_camera: Camera3D = $Eye/Camera/GunVPContainer/GunVP/GunCam
@onready var gun_vp: SubViewport = $Eye/Camera/GunVPContainer/GunVP
@onready var name_label: Label3D = $Name
@onready var weapon_handler: WeaponHandler = $Eye/Camera/WeaponHandler
@onready var camera_anchor: Marker3D = $CameraAnchor
@onready var third_person: Node3D = $ThirdPerson

@export var back_btn: Button
@export var ui: CanvasLayer
@export var crosshair: Control
@export var sniper_overlay: TextureRect
@export var main_menu_btn: Button
@export var pause_menu: Control
@export var bone_simulator: PhysicalBoneSimulator3D
@export var ragdoll_camera: Camera3D

const RunSound := preload("res://src/sounds/run.mp3")
const MAX_G_SPEED := 5.5
const MAX_G_ACCEL := MAX_G_SPEED * 8
const MAX_A_SPEED := 0.8
const MAX_A_ACCEL: float = 220
const MAX_SLOPE: float = 1
const JUMP_FORCE: float = 4
const RUN_SOUND_DELAY := 0.4
const MAX_HEALTH := 100.0
const MAX_PRE := 7.5

var _time_since_last_jump := 0.0
var _time_since_last_run_sound := RUN_SOUND_DELAY
var gravity: float = 12
var pid: int
var _run_audio_player := AudioStreamPlayer.new()
var can_move := true
var can_turn := true
var health := MAX_HEALTH
var is_dead := false
var is_pre_capped: bool
var hardcore := true

func player_name() -> String:
	return get_node("Name").text

@rpc("call_remote", "any_peer", "reliable")
func on_damage(value: float, weapon_name: String) -> void:
	health -= value
	damaged.emit(health)

	if not Global.is_sv(): return
	if is_dead: return

	var sender := multiplayer.get_remote_sender_id()

	if health <= 0:
		dead.emit(sender, pid, weapon_name)

@rpc("call_local", "authority", "reliable")
func ragdoll() -> void:
	bone_simulator.physical_bones_start_simulation()
	is_dead = true
	can_move = false
	weapon_handler.weapon_scene.visible = false

	if is_me():
		if sniper_overlay.visible:
			weapon_handler.toggle_sniper_scope()

		ragdoll_camera.current = true
		weapon_handler.visible = false

@rpc("call_local", "authority", "reliable")
func respawn() -> void:
	bone_simulator.physical_bones_stop_simulation()
	is_dead = false
	can_move = true
	weapon_handler.weapon_scene.visible = true
	health = MAX_HEALTH
	damaged.emit(health)

	if is_me():
		weapon_handler.reset_ammo()
		camera.current = true
		weapon_handler.visible = true

func on_death() -> void:
	pass

func is_me() -> bool:
	if not Global.multiplayer.multiplayer_peer:
		return pid == 1

	return multiplayer.get_unique_id() == pid

func set_name_label(value: String) -> void:
	name_label.text = value

# This only gets called on the player we are controlling
func setup() -> void:
	camera.make_current()
	gun_camera.make_current()
	pid = Global.id()
	weapon_handler.visible = true
	weapon_handler.add_child(weapon_handler.audio)
	add_child(_run_audio_player)
	third_person.visible = false
	name_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	for child: PhysicalBone3D in bone_simulator.get_children():
		child.collision_layer = 0

	main_menu_btn.pressed.connect(
		func() -> void:
			get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")
	)

	back_btn.pressed.connect(toggle_pause)

	ui.visible = true

func _on_viewport_resized() ->  void:
	var window_size := get_viewport().get_visible_rect().size
	gun_vp.size = window_size

func _ready() -> void:
	camera.current = false
	gun_camera.current = false
	weapon_handler.visible = false
	pause_menu.visible = false
	ui.visible = false
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

func toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	toggled_pause.emit(pause_menu.visible)
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_menu.visible else Input.MOUSE_MODE_CAPTURED

	#crosshair.visible = not (requires_unlock() or game.requires_unlock())

func requires_unlock() -> bool:
	return pause_menu.visible

func _process(delta: float) -> void:
	if not is_me(): return

	if Input.is_action_just_pressed("pause"):
		toggle_pause()
	
	_time_since_last_run_sound += delta
	_time_since_last_jump += delta

func is_paused() -> bool:
	return pause_menu.visible

func _physics_process(delta: float) -> void:
	if not is_me(): return
	
	var jump_input := Input.is_action_just_pressed("jump") or Input.is_action_pressed("jump")
	_movement_process(delta, wish_dir(), jump_input)
	
	if Global.mp():
		_update_state.rpc(global_position, global_rotation.y, camera.global_rotation.x, get_ups())

@rpc("any_peer", "call_remote", "unreliable")
func _update_state(pos: Vector3, rot_y: float, rot_x: float, speed: float) -> void:
	global_position = pos
	camera._input_rotation.y = rot_y
	camera._input_rotation.x = rot_x
	weapon_handler.weapon_scene.get_parent().rotation.x = rot_x
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
	var vel_vertical := _apply_gravity(velocity.y, delta)

	wish_dir = wish_dir.rotated(-rotation.y)
	var vel_planar := Vector2(velocity.x, velocity.z)
	
	vel_planar = _apply_friction(vel_planar, delta, wish_dir, jump_input)
	vel_planar = _update_velocity(vel_planar, wish_dir, delta, jump_input)
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
	return test_move(global_transform, Vector3(0, -0.01, 0))

func _apply_friction(vel_planar: Vector2, delta: float, wish_dir: Vector2, jump_input: bool) -> Vector2:
	if not grounded() or jump_input: return vel_planar
	
	var v: Vector2 = vel_planar - vel_planar.normalized() * delta * MAX_G_ACCEL / 1.9

	if v.length_squared() < 1.0 and wish_dir.length_squared() < 0.01:
		return Vector2.ZERO
	else:
		return v

func _update_velocity(vel_planar: Vector2, wish_dir: Vector2, delta: float, jump_input: bool) -> Vector2:
	var current_speed := vel_planar.dot(wish_dir)
	var max_speed := MAX_G_SPEED if grounded() else MAX_A_SPEED
	var max_accel := MAX_G_ACCEL if grounded() else MAX_A_ACCEL
	var add_speed: float = clamp(max_speed - current_speed, 0.0, max_accel * delta)
	
	var new_vel := vel_planar + wish_dir * add_speed
	
	if grounded() and not jump_input and is_pre_capped:
		new_vel = new_vel.limit_length(MAX_PRE)
		
	return new_vel

func _check_for_jump(vel_vertical: float, jump_input: bool) -> float:
	if jump_input and grounded():
		jumped.emit()
		_time_since_last_jump = 0.0
		return JUMP_FORCE

	return vel_vertical
