extends Control

var url = Settings.base_url + "user/"
var state = 0

func _ready():
	check_for_save_file()
	$Request.request_completed.connect(handle_request)
	$Submit.pressed.connect(login)
	$Submit.pressed.connect(register)
	$StateSwitcher.pressed.connect(switch_state)
	
func switch_state():
	if state == 0:
		state = 1
		$Submit.text = "Register"
		$StateSwitcher.text = "Already have an account?"
	else:
		state = 0
		$Submit.text = "Login"
		$StateSwitcher.text = "Don't have an account?"

func check_for_save_file():
	var save_file = FileAccess.open(Settings.save_file, FileAccess.READ)
	
	if save_file != null:
		var uuid = save_file.get_as_text()
		Settings.uuid = uuid
		get_tree().change_scene_to_file("res://menus/level_select/level_select.tscn")

func save_uuid(uuid):
	var save_file = FileAccess.open(Settings.save_file, FileAccess.WRITE_READ)
	save_file.store_string(uuid)
	Settings.uuid = uuid
	check_for_save_file()

func register():
	if state != 1: return
	print('Registering')
	account_request("register")

func login():
	if state != 0: return
	print('Logging In')
	account_request("login")
	
func account_request(url_end):
	var body = JSON.stringify({
			"username": $Username.text,
			"password": $Password.text,
	})
	
	var headers = ["Content-Type: application/json"]
	$Request.request(url + url_end, headers, HTTPClient.METHOD_POST, body)
	
	
func handle_request(result, response_code, headers, body):
	print(body.get_string_from_utf8())
	if response_code == 200:
		save_uuid(body.get_string_from_utf8())
