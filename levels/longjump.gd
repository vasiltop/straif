extends Node

var url = Settings.base_url + "longjump/leaderboard"
var leaderboard = "Could not connect to server."

func _ready():
	$GetLeaderboard.request_completed.connect(handle_request)
	$GetLeaderboard.request(url)

func handle_request(result, response_code, headers, body):
	if response_code != 200: return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	leaderboard = ""
	
	for jump in json:
		leaderboard += jump.username + " | " + str(snapped(jump.length / 1000, 0.01)) + "u	\n"

func _process(delta):
	if Input.is_action_pressed("leaderboard"):
		$Leaderboard.text = leaderboard
	else:
		$Leaderboard.text = ""
