class_name Player extends CharacterBody3D

signal jumped

@onready var camera: Camera3D = $Camera
@onready var timer_label: Label = $UI/Timer
@onready var map: Map = $".."

const MAX_G_SPEED := 4.3
const MAX_G_ACCEL := MAX_G_SPEED * 8
const MAX_A_SPEED := 0.7
const MAX_A_ACCEL: float = 200
const MAX_SLOPE: float = 1
const JUMP_FORCE: float = 4

var gravity: float = 11

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_mouse_mode"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE

	if Input.is_action_just_pressed("main_menu"):
		get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_movement_process(delta)

func _physics_process(_delta: float) -> void:
	for member in Lobby.lobby_members:
		if map.player_exists(member.id):
			map.moved.rpc(global_position)

func set_timer(value: float) -> void:
	timer_label.text = str(snapped(value, 0.001)) + " s"

func _movement_process(delta: float) -> void:
	var wish_dir := Input.get_vector("left", "right", "up", "down")
	wish_dir = wish_dir.rotated(-rotation.y)

	var vel_planar := Vector2(velocity.x, velocity.z)
	var vel_vertical := _apply_gravity(velocity.y, delta)
	vel_planar = _apply_friction(vel_planar, delta, wish_dir)
	vel_planar = _update_velocity_ground(vel_planar, wish_dir, delta)
	vel_vertical = _check_for_jump(vel_vertical)

	velocity = Vector3(vel_planar.x, vel_vertical, vel_planar.y)
	
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
	var jump_input := Input.is_action_pressed("jump")

	if jump_input and grounded():
		jumped.emit()
		return JUMP_FORCE

	return vel_vertical

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_look(event as InputEventMouseMotion)
	
func _look(event: InputEventMouseMotion) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return

	var sens := 0.0006
	rotate(Vector3(0, -1, 0), event.relative.x * sens)
	camera.rotate_x(-event.relative.y * sens)
	camera.rotation.y = 0
	camera.rotation.z = 0
	camera.rotation.x = clamp(camera.global_rotation.x, deg_to_rad(-90), deg_to_rad(90))
