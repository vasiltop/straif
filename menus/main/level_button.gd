extends Button

func _ready():
	pressed.connect(on_click)

func set_label(name: String):
	text = name

func on_click():
	get_tree().change_scene_to_file("res://levels/" + text + ".tscn")	
