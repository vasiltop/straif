extends CharacterBody3D


const MAX_G_SPEED = 7
const MAX_G_ACCEL = MAX_G_SPEED * 15

const MAX_A_SPEED = 1
const MAX_A_ACCEL = 70

const JUMP_FORCE = 4.5
@onready var camera = $Camera3D
@onready var speed_label = $Speed

const SENS = 0.0004
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func grounded():
	var origin = global_position
	var target = Vector3.DOWN * 1
	
	var query = PhysicsRayQueryParameters3D.create(origin, origin + target)
	var check = get_world_3d().direct_space_state.intersect_ray(query)
	
	return check.size() > 0

func _physics_process(delta):
	
	
	print(velocity)
	var wish_dir = Input.get_vector("left", "right", "up", "down")
	wish_dir = wish_dir.rotated(-rotation.y)
	var vel_planar = Vector2(velocity.x, velocity.z)
	var vel_vertical = velocity.y
	

	if not grounded():
		vel_vertical -= gravity * delta
	else:
		vel_vertical = 0
		vel_planar -= vel_planar.normalized() * delta * MAX_G_ACCEL / 4
		
		if vel_planar.length_squared() < 1.0 and wish_dir.length_squared() < 0.01:
			vel_planar = Vector2.ZERO
		
	var current_speed = vel_planar.dot(wish_dir)
	
	var max_speed = MAX_G_SPEED if grounded() else MAX_A_SPEED
	var max_accel = MAX_G_ACCEL if grounded() else MAX_A_ACCEL
	var add_speed = clamp(max_speed - current_speed, 0.0, max_accel * delta)
	vel_planar += wish_dir * add_speed
	
	if Input.is_action_pressed("jump") and grounded():
		vel_vertical = JUMP_FORCE
	
	velocity = Vector3(vel_planar.x, vel_vertical, vel_planar.y)
	speed_label.text = str(snapped(abs(velocity.x) + abs(velocity.z), 0.1)) + " u/s"
	move_and_collide(velocity * delta)

	
func _input(event):
	if event is InputEventMouseMotion:
		rotate(Vector3(0, -1, 0), event.relative.x * SENS)
		camera.rotate(Vector3(-1, 0, 0), event.relative.y * SENS)
		camera.rotation.x = clamp(camera.rotation.x, -1, 1.5)
