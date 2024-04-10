extends Control

@onready var lj = $longjump
@onready var bh = $bhop
@onready var bh2 = $bhop2

var url = "http://192.168.2.16:8000/user"

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	lj.pressed.connect(longjump)
	bh.pressed.connect(bhop)
	bh2.pressed.connect(bhop2)
	
	var save_file = FileAccess.open('user://source.data', FileAccess.READ)
	
	if save_file == null:
		print(FileAccess.get_open_error())
		$username.visible = true
		$logout.visible = false
		$submit_username.visible = true
		$submit_username.pressed.connect(create_user)
		$CreateUser.request_completed.connect(save_uuid)
	else:
		$logout.pressed.connect(logout)
		var uuid = save_file.get_as_text()
		User.uuid = uuid

func logout():
	DirAccess.remove_absolute('user://source.data')
	$username.visible = true
	$logout.visible = false
	$submit_username.visible = true
	$submit_username.pressed.connect(create_user)
	$CreateUser.request_completed.connect(save_uuid)
	
func save_uuid(result, response_code, headers, body):
	print(response_code)
	if response_code != 200:
		return
		
	var save_file = FileAccess.open('user://source.data', FileAccess.WRITE_READ)
	var json = JSON.parse_string(body.get_string_from_utf8())
	print(json)
	save_file.store_string(json.id)
	User.uuid = json.id
	$username.visible = false
	$submit_username.visible = false

func create_user():
	var body = JSON.stringify({
			"username": $username.text,
	})
	print(body)
	var headers = ["Content-Type: application/json"]
	$CreateUser.request(url, headers, HTTPClient.METHOD_POST, body)
	
func longjump():
	get_tree().change_scene_to_file("res://longjump.tscn")
	
func bhop():
	get_tree().change_scene_to_file("res://levels/1.tscn")
	
func bhop2():
	get_tree().change_scene_to_file("res://levels/2.tscn")
	
func _process(delta):
	pass
