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
	if player.map.is_watching_replay(): return
	
	if _remaining > 0:
		_remaining -= delta
		h_offset = randf_range(-_magnitude, _magnitude)
		v_offset = randf_range(-_magnitude, _magnitude)
	else:
		h_offset = 0
		v_offset = 0

	global_transform = player.camera_anchor.get_global_transform_interpolated()
	player.gun_camera.global_transform = global_transform
	
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	_input_rotation.x = clampf(_input_rotation.x + _mouse_input.y, deg_to_rad(-90), deg_to_rad(85))
	_input_rotation.y += _mouse_input.x
	
	player.camera_anchor.transform.basis = Basis.from_euler(Vector3(_input_rotation.x, 0.0, 0.0))
	player.global_transform.basis = Basis.from_euler(Vector3(0.0, _input_rotation.y, 0.0))
	
	_mouse_input = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not player.is_me(): return
	if player.leaderboard.middle.visible: return
	
	var sens: float = Settings.value("Controls", "sensitivity" if not player.sniper_overlay.visible else "ads_sensitivity")
	sens = sens / 1000
	
	if event is InputEventMouseMotion:
		var ev := event as InputEventMouseMotion
		_mouse_input.x += -ev.screen_relative.x * sens
		_mouse_input.y += -ev.screen_relative.y * sens
