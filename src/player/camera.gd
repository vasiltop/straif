class_name PlayerCamera extends Camera3D

@onready var player: Player = $"../.."

var _remaining: float
var _magnitude: float
var _mouse_input: Vector2
var _input_rotation: Vector3

func shake(duration: float, magnitude: float) -> void:
	_remaining = duration
	_magnitude = magnitude

func _process(delta: float) -> void:
	if not player.is_me(): return
	
	if _remaining > 0:
		_remaining -= delta
		h_offset = randf_range(-_magnitude, _magnitude)
		v_offset = randf_range(-_magnitude, _magnitude)
	else:
		h_offset = 0
		v_offset = 0
	
	_input_rotation.x = clampf(_input_rotation.x + _mouse_input.y, deg_to_rad(-90), deg_to_rad(85))
	_input_rotation.y += _mouse_input.x
	
	player.camera_anchor.transform.basis = Basis.from_euler(Vector3(_input_rotation.x, 0.0, 0.0))
	player.global_transform.basis = Basis.from_euler(Vector3(0.0, _input_rotation.y, 0.0))
	global_transform = player.camera_anchor.get_global_transform_interpolated()
	player.gun_camera.global_transform = global_transform
	
	_mouse_input = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not player.is_me(): return
	var sens: float = Settings.value("Controls", "sensitivity") / 1000
	
	if event is InputEventMouseMotion:
		var ev := event as InputEventMouseMotion
		_mouse_input.x += -ev.screen_relative.x * sens
		_mouse_input.y += -ev.screen_relative.y * sens
	
	'''
	func _input(event: InputEvent) -> void:
	if not is_me(): return

	if event is InputEventMouseMotion:
		_look(event as InputEventMouseMotion)
	
func _look(event: InputEventMouseMotion) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return

	var sens: float = Settings.value("Controls", "sensitivity") / 1000
	rotate(Vector3(0, -1, 0), event.relative.x * sens)
	camera_anchor.rotate_x(-event.relative.y * sens)
	camera_anchor.rotation.y = 0
	camera_anchor.rotation.z = 0
	camera_anchor.rotation.x = clamp(camera_anchor.global_rotation.x, deg_to_rad(-90), deg_to_rad(90))'''
