@tool
class_name Eyebrow extends Label

func _init() -> void:
	theme_type_variation = &"Eyebrow"

func _ready() -> void:
	text = text.to_upper()

func set_label(value: String) -> void:
	text = value.to_upper()
