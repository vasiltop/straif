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
		# This prevents the bug where the uuid can be "" after logging in
		if Settings.uuid == "":
			Settings.uuid = uuid
		get_tree().change_scene_to_file("res://levels/rookie.tscn")

func save_uuid(uuid):
	var save_file = FileAccess.open(Settings.save_file, FileAccess.WRITE)
	save_file.store_string(uuid)
	Settings.uuid = uuid
	check_for_save_file()

func register():
	if state != 1: return
	account_request("register")

func login():
	if state != 0: return
	account_request("login")
	
func account_request(url_end):
	var body = JSON.stringify({
			"username": $Username.text,
			"password": $Password.text,
	})
	
	var headers = ["Content-Type: application/json"]
	$Request.request(url + url_end, headers, HTTPClient.METHOD_POST, body)
	
	
func handle_request(result, response_code, headers, body):
	if response_code != 200:
		$Error.text = body.get_string_from_utf8()
		return
	
	save_uuid(body.get_string_from_utf8())
	
