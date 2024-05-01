extends Control

var levels = ["dawn.tscn", "fog.tscn", "longjump.tscn", "rookie.tscn"]
var current_level = 0

func _ready():
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	$Prev.pressed.connect(prev_map)
	$Next.pressed.connect(next_map)
	$StartLevel.pressed.connect(start_map)
	$Logout.pressed.connect(logout)
	
	update_level_labels()

func next_map():
	current_level = current_level + 1 if current_level < len(levels) - 1 else 0
	update_level_labels()
	
func prev_map():
	current_level = current_level - 1 if current_level > 0 else len(levels) - 1
	update_level_labels()
	
func start_map():
	get_tree().change_scene_to_file("res://levels/" + levels[current_level])

func update_level_labels():
	$StartLevel.text = "Start Level: " + levels[current_level]

func logout():
	print("logging out")
	DirAccess.remove_absolute('user://straif.data')
	get_tree().change_scene_to_file("res://menus/account/account.tscn")

