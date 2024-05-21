extends Button

func _ready():
	pressed.connect(on_click)

func set_label(name: String):
	text = name

func on_click():
	get_tree().change_scene_to_file("res://levels/" + text + ".tscn")	

func set_difficulty(amount: int):
	$Difficulty.text = "Difficulty: " + str(amount) + "/5"

func set_mapper(name: String):
	$Mapper.text = "Mapper: " + name
