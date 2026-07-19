@tool
class_name Scrim extends Control

@export_range(0.0, 1.0) var dim: float = 0.55:
	set(value):
		dim = value
		queue_redraw()

@export_range(0.0, 1.0) var vignette: float = 0.65:
	set(value):
		vignette = value
		queue_redraw()

var _cached_tex: GradientTexture2D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.with_alpha(Palette.BACKGROUND, dim))
	draw_texture_rect(_vignette_texture(), r, false, Color(1, 1, 1, vignette))

func _vignette_texture() -> GradientTexture2D:
	if _cached_tex != null:
		return _cached_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray(
			[
				Palette.with_alpha(Palette.BACKGROUND, 0.0),
				Palette.with_alpha(Palette.BACKGROUND, 0.0),
				Palette.with_alpha(Palette.BACKGROUND, 1.0),
			]
	)
	var t := GradientTexture2D.new()
	t.gradient = grad
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 1.05)
	t.width = 256
	t.height = 256
	_cached_tex = t
	return t
