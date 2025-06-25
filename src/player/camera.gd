class_name PlayerCamera extends Camera3D

var _remaining: float
var _magnitude: float

func shake(duration: float, magnitude: float) -> void:
	_remaining = duration
	_magnitude = magnitude

func _process(delta: float) -> void:
	if _remaining > 0:
		_remaining -= delta
		h_offset = randf_range(-_magnitude, _magnitude)
		v_offset = randf_range(-_magnitude, _magnitude)
	else:
		h_offset = 0
		v_offset = 0
