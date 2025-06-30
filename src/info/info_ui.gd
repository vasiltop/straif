class_name InfoUi extends Panel

@onready var label: Label = $CenterContainer/Label

func set_message(message: String) -> void:
	if not label: return
	
	label.text = message
