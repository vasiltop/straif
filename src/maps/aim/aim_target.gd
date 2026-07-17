class_name AimTarget
extends StaticBody3D

signal hit(target: AimTarget, hit_position: Vector3, reaction_time: float)

@export var motion_extent := Vector2(3.2, 1.6)
@export var motion_speed := 1.0

@onready var visual: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var active := false
var available_since := 0.0
var motion_enabled := false
var motion_center := Vector3.ZERO
var motion_phase := Vector2.ZERO
var _motion_time := 0.0

func _ready() -> void:
	_apply_state()

func activate(at_position: Vector3, spawn_time: float) -> void:
	global_position = at_position
	available_since = spawn_time
	active = true
	motion_enabled = false
	_motion_time = 0.0
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

func configure_tracking_motion(center: Vector3, extent: Vector2, speed: float, phase: Vector2 = Vector2.ZERO) -> void:
	motion_center = center
	motion_extent = extent
	motion_speed = speed
	motion_phase = phase
	motion_enabled = true
	_motion_time = 0.0
	global_position = center

func update_tracking_motion(delta: float) -> void:
	if not active or not motion_enabled:
		return

	_motion_time += delta * motion_speed
	global_position = motion_center + Vector3(
		sin(_motion_time + motion_phase.x) * motion_extent.x,
		cos(_motion_time * 0.82 + motion_phase.y) * motion_extent.y,
		0.0
	)

func _apply_state() -> void:
	visible = active
	collision_layer = 4 if active else 0
	collision_mask = 0
	collision_shape.disabled = not active
	if visual != null:
		visual.visible = active
