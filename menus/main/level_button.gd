extends Button

var map_name: String = ""

func _ready():
	
	$Replay.pressed.connect(view_replay)
	pressed.connect(on_click)

func view_replay():
	if Save.data[map_name]['replay'] == null: return
	SceneManager.replay_when_level_started = true
	get_tree().change_scene_to_file("res://levels/" + map_name + ".tscn")

func set_label(name: String):
	map_name = name
	text = name
	if Save.data[map_name]['replay'] == null:
		#$Replay.pressed.disconnect(view_replay)
		$Replay.visible = false
	var time = Save.data[name]["pr"]
	$Pr.text = "Personal Record: " + (str(time) if time != null else "None")

func on_click():
	get_tree().change_scene_to_file("res://levels/" + text + ".tscn")	

func set_difficulty(amount: int):
	$Difficulty.text = "Difficulty: " + str(amount) + "/5"

func set_mapper(name: String):
	$Mapper.text = "Mapper: " + name
