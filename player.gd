extends CharacterBody3D

@onready var camera = $Camera3D
@onready var speed_label = $Speed
@onready var RAY_POS = $RaycastPos.position

const MAX_G_SPEED = 5
const MAX_G_ACCEL = MAX_G_SPEED * 13
const MAX_A_SPEED = 1
const MAX_A_ACCEL = 50
const MAX_SLOPE = 1
const JUMP_FORCE = 4
const RAY_REACH = 0.1
var gravity = 11

const SENS = 0.0004

var floor_col_pos = Vector3.ZERO

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func grounded():
	var origin = global_position + RAY_POS
	var target = Vector3.DOWN * RAY_REACH
	
	var query = PhysicsRayQueryParameters3D.create(origin, origin + target)
	var check = get_world_3d().direct_space_state.intersect_ray(query)
	floor_col_pos = check
	return check.size() > 0
	
func get_slope_angle(normal): return normal.angle_to(up_direction)

func _physics_process(delta):
	
	#print(velocity)
	var wish_dir = Input.get_vector("left", "right", "up", "down")
	wish_dir = wish_dir.rotated(-rotation.y)
	var vel_planar = Vector2(velocity.x, velocity.z)
	var vel_vertical = velocity.y
	
	if not grounded():
		vel_vertical -= gravity * delta
	else:
		
		vel_planar -= vel_planar.normalized() * delta * MAX_G_ACCEL / 2
		
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
	
	var col = move_and_collide(velocity * delta)
	
	
	if col:
		
		var slope_angle = get_slope_angle(col.get_normal())
		
		#Surfing
		if slope_angle < MAX_SLOPE:
			velocity.y = 0.0
			move_and_collide(col.get_remainder().slide(col.get_normal()))
			if not grounded():
				velocity = velocity.slide(col.get_normal())
		else:
			move_and_slide()	
					
	elif grounded():
		move_and_collide(floor_col_pos.position - global_position)

func _input(event):
	if event is InputEventMouseMotion:
		rotate(Vector3(0, -1, 0), event.relative.x * SENS)
		camera.rotate(Vector3(-1, 0, 0), event.relative.y * SENS)
		camera.rotation.x = clamp(camera.rotation.x, -1, 1.5)
