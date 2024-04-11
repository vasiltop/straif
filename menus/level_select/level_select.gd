extends Control

var url = "http://192.168.2.16:8000/user"
var levels = ["dawn.tscn", "fog.tscn", "longjump.tscn", "rookie.tscn"]
var current_level = 0

func _ready():
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	$Prev.pressed.connect(prev_map)
	$Next.pressed.connect(next_map)
	$StartLevel.pressed.connect(start_map)
	
	check_for_save_file()
	update_level_labels()

func check_for_save_file():
	var save_file = FileAccess.open('user://source.data', FileAccess.READ)
	
	if save_file == null:
		$username.visible = true
		$logout.visible = false
		$submit_username.visible = true
		$submit_username.pressed.connect(create_user)
		$CreateUser.request_completed.connect(save_uuid)
	else:
		$logout.pressed.connect(logout)
		var uuid = save_file.get_as_text()
		Settings.uuid = uuid
		
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
	DirAccess.remove_absolute('user://source.data')
	$username.visible = true
	$logout.visible = false
	$submit_username.visible = true
	$submit_username.pressed.connect(create_user)
	$CreateUser.request_completed.connect(save_uuid)
	
func save_uuid(result, response_code, headers, body):
	if response_code != 200:
		return
		
	var save_file = FileAccess.open('user://source.data', FileAccess.WRITE_READ)
	var json = JSON.parse_string(body.get_string_from_utf8())
	save_file.store_string(json.id)
	Settings.uuid = json.id
	$username.visible = false
	$submit_username.visible = false

func create_user():
	var body = JSON.stringify({
			"username": $username.text,
	})
	print(body)
	var headers = ["Content-Type: application/json"]
	$CreateUser.request(url, headers, HTTPClient.METHOD_POST, body)
