class_name InfoUi extends PanelContainer

@onready var label: Label = $MarginContainer/CenterContainer/Label

func set_message(message: String) -> void:
	if not label: return
	
	label.text = message
