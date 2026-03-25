class_name ClickableLabel extends Label

signal pressed

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	var mbe := event as InputEventMouseButton
	if event is InputEventMouseButton and mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
