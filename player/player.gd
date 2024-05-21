extends CharacterBody3D

@onready var camera = $Camera3D
@onready var speed_label = $Speed
@onready var last_jump_label = $LastJump
@onready var audio_player = $Audio
@onready var recorder = get_parent().get_node("Recorder")

var landing = preload("res://sound/landing.wav")

const MAX_G_SPEED = 5
const MAX_G_ACCEL = MAX_G_SPEED * 10
const MAX_A_SPEED = 0.7
const MAX_A_ACCEL = 100
const MAX_SLOPE = 1
const JUMP_FORCE = 4
const RAY_REACH = 0.1
const POSITION_PACKET_DELAY: float = 0.01

var gravity = 11
var floor_col_pos = Vector3.ZERO
var last_jump = 0
var last_jump_pos = Vector3.ZERO
var jumped = false
var prev_pos = Vector3.ZERO
var camera_height = 0
var time_since_landing = 0
var url = Settings.base_url + "longjump/"
var time_since_last_position_packet: float = 0
var movement_paused: bool = false
var longjump_counts = false
var kz_jump_style: bool = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	prev_pos = camera.position
	camera_height = camera.position.y

func grounded():
	return test_move(global_transform, Vector3(0, -0.01, 0))
	
func get_slope_angle(normal): return normal.angle_to(up_direction)

func _process(delta):
	update_timers(delta)
	
	interpolate_camera_pos(delta)
	handle_scene_changes()

func handle_scene_changes():
		
	if Input.is_action_just_pressed("pause"):
		SceneManager.change_scene(SceneManager.SCENES.MAIN_MENU)

func interpolate_camera_pos(delta):
	var camera_pos = prev_pos.lerp(position, delta * 70)
	camera.global_position = camera_pos
	camera.position.y = camera_height
	prev_pos = camera_pos

func update_timers(delta):
	time_since_last_position_packet += delta
	if not jumped and grounded():
		time_since_landing += delta

func is_map_longjump():
	return get_tree().current_scene.name == "Longjump"
	
func submit_to_leaderboard(length):
	if not is_map_longjump(): return
	
	recorder.stop()
	var r = recorder.save(floor(last_jump * 1000))
	var body = r.to_bytes()
	
	var headers = ["Content-Type: application/json", "password: " + Settings.password, "auth_ticket: " + SteamClient.auth_ticket_hex]
	$PostLeaderboard.request_raw(url + "publish", headers, HTTPClient.METHOD_POST, body)

func check_for_landing():
	if not grounded(): return
	if not jumped: return 
	
	audio_player.stream = landing
	audio_player.play()
	jumped = false
	if time_since_landing > 0.6 and snapped(global_position.y, 0.01) == snapped(last_jump_pos.y, 0.01) and longjump_counts:
		last_jump = last_jump_pos.distance_to(global_position)
		last_jump_label.text = str(snapped(last_jump, 0.01)) + " u"
		submit_to_leaderboard(last_jump)
		longjump_counts = false
	time_since_landing = 0

func apply_gravity(velocity_y: float, delta: float) -> float:
	if grounded(): return velocity_y
	return velocity_y - gravity * delta

func apply_friction(vel_planar: Vector2, delta: float, wish_dir: Vector2) -> Vector2:
	if not grounded(): return vel_planar
	if Input.is_action_pressed("jump"): return vel_planar
	
	var v = vel_planar - vel_planar.normalized() * delta * MAX_G_ACCEL / 2

	if v.length_squared() < 1.0 and wish_dir.length_squared() < 0.01:
		return Vector2.ZERO
	else:
		return v

func update_velocity_ground(vel_planar: Vector2, wish_dir: Vector2, delta: float):
	var current_speed = vel_planar.dot(wish_dir)
	var max_speed = MAX_G_SPEED if grounded() else MAX_A_SPEED
	var max_accel = MAX_G_ACCEL if grounded() else MAX_A_ACCEL
	var add_speed = clamp(max_speed - current_speed, 0.0, max_accel * delta)
	return vel_planar + wish_dir * add_speed
	
func _physics_process(delta):
	if movement_paused: return
	
	var wish_dir = Input.get_vector("left", "right", "up", "down")
	wish_dir = wish_dir.rotated(-rotation.y)
	var vel_planar: Vector2 = Vector2(velocity.x, velocity.z)
	
	check_for_landing()
	
	var vel_vertical = apply_gravity(velocity.y, delta)
	vel_planar = apply_friction(vel_planar, delta, wish_dir)
	vel_planar = update_velocity_ground(vel_planar, wish_dir, delta)
	vel_vertical = check_for_jump(vel_vertical)

	velocity = Vector3(vel_planar.x, vel_vertical, vel_planar.y)
	
	update_ui()
	move_and_slide()
	update_position_to_lobby()

func update_ui():
	speed_label.text = str(snapped(abs(velocity.x) + abs(velocity.z), 0.1)) + " u/s"
	
func update_position_to_lobby():
	if time_since_last_position_packet > POSITION_PACKET_DELAY:
			Packet.send({"type": Packet.PACKET.POSITION, "map_name": get_tree().current_scene.name, "pos": position})
			time_since_last_position_packet = 0

func check_for_jump(vel_vertical) -> float:
	var v = abs(velocity.x) + abs(velocity.z)
	var jump_input = (Input.is_action_pressed("jump") or Input.is_action_just_pressed("jump")) if not kz_jump_style else Input.is_action_just_pressed("jump")
	
	if jump_input and grounded() and not jumped:
		if v < 12 and is_map_longjump():
			recorder.start()
			longjump_counts = true
		last_jump_pos = global_position
		jumped = true
		return JUMP_FORCE
	else:
		return vel_vertical
		
func _input(event):
	if movement_paused: return
	
	if event is InputEventMouseMotion:
		rotate_player(event)

func rotate_player(event):
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	rotate(Vector3(0, -1, 0), event.relative.x * Settings.sens)
	camera.rotate_x(-event.relative.y * Settings.sens)
	camera.rotation.y = 0
	camera.rotation.z = 0
	camera.rotation.x = clamp(camera.global_rotation.x, deg_to_rad(-90), deg_to_rad(90))
