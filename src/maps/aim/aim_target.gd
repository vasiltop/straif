class_name AimTarget
extends StaticBody3D

signal hit(target: AimTarget, hit_position: Vector3, reaction_time: float)

@export var motion_extent := Vector2(3.2, 1.6)

@onready var visual: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var active := false
var available_since := 0.0
var motion_enabled := false
var motion_center := Vector3.ZERO
var tracking_speed_range := Vector2(4.0, 7.5)
var tracking_direction_interval := Vector2(0.3, 0.75)
var _tracking_velocity := Vector3.ZERO
var _tracking_dir_timer := 0.0
var _tracking_local := Vector3.ZERO

func _ready() -> void:
	_apply_state()

func activate(at_position: Vector3, spawn_time: float) -> void:
	global_position = at_position
	available_since = spawn_time
	active = true
	motion_enabled = false
	_tracking_local = Vector3.ZERO
	_apply_state()

func deactivate() -> void:
	active = false
	motion_enabled = false
	_apply_state()

func register_hit(hit_position: Vector3, current_time: float) -> bool:
	if not active:
		return false

	var reaction_time := maxf(current_time - available_since, 0.0)
	deactivate()
	hit.emit(self, hit_position, reaction_time)
	return true

func configure_tracking_motion(center: Vector3, extent: Vector2, speed_range: Vector2, direction_interval: Vector2) -> void:
	motion_center = center
	motion_extent = extent
	tracking_speed_range = speed_range
	tracking_direction_interval = direction_interval
	motion_enabled = true
	_tracking_local = Vector3.ZERO
	_tracking_dir_timer = 0.0
	global_position = center
	_pick_new_tracking_velocity()

func _pick_new_tracking_velocity() -> void:
	var angle := randf_range(0.0, TAU)
	var speed := randf_range(tracking_speed_range.x, tracking_speed_range.y)
	_tracking_velocity = Vector3(cos(angle), sin(angle), 0.0) * speed
	_tracking_dir_timer = randf_range(tracking_direction_interval.x, tracking_direction_interval.y)

func update_tracking_motion(delta: float) -> void:
	if not active or not motion_enabled:
		return

	_tracking_dir_timer -= delta
	if _tracking_dir_timer <= 0.0:
		_pick_new_tracking_velocity()

	_tracking_local += _tracking_velocity * delta

	if _tracking_local.x > motion_extent.x:
		_tracking_local.x = motion_extent.x
		_tracking_velocity.x = -_tracking_velocity.x
	elif _tracking_local.x < -motion_extent.x:
		_tracking_local.x = -motion_extent.x
		_tracking_velocity.x = -_tracking_velocity.x

	if _tracking_local.y > motion_extent.y:
		_tracking_local.y = motion_extent.y
		_tracking_velocity.y = -_tracking_velocity.y
	elif _tracking_local.y < -motion_extent.y:
		_tracking_local.y = -motion_extent.y
		_tracking_velocity.y = -_tracking_velocity.y

	global_position = motion_center + _tracking_local

func _apply_state() -> void:
	visible = active
	collision_layer = 4 if active else 0
	collision_mask = 0
	collision_shape.disabled = not active
	if visual != null:
		visual.visible = active
