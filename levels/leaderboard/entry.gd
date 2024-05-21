extends Container
			
var steam_id: int = 0
var is_longjump = false
var map_name = ""
const run = preload("res://run.gd")

func _ready():
	$DemoRequest.request_completed.connect(handle_demo)
	
func initialize(username, value, steam_id, map_name, is_longjump = false):
	get_node("Label").text = username + " | " + str(float(value) / 1000)
	get_node("Button").pressed.connect(on_replay_clicked)	
	self.steam_id = steam_id
	self.is_longjump = is_longjump
	self.map_name = map_name

func on_replay_clicked():
	get_demo()

func get_demo():
	var body = null
	var url = ""
	if is_longjump:
		url = Settings.base_url + "longjump/"
		body = JSON.stringify({
				"steam_id": steam_id
		})	
	else:
		url = Settings.base_url + "bhop/"
		body = JSON.stringify({
				"map_name": map_name,
				"steam_id": steam_id
		})
	var headers = ["Content-Type: application/json"]
	$DemoRequest.request(url + "demo", headers, HTTPClient.METHOD_POST, body)

func handle_demo(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	var r = run.Run.new()
	var result_code = r.from_bytes(json[0])
	get_parent().get_parent().get_node("Recorder").replay(r.get_frames())
