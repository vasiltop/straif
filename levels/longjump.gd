extends Node

var url = Settings.base_url + "longjump/leaderboard"
var leaderboard = ""

func _ready():	
	$GetLeaderboard.request_completed.connect(handle_request)
	$GetLeaderboard.request(url)

func handle_request(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())

	for jump in json:
		leaderboard += jump.username + " | " + str(snapped(jump.length / 100, 0.01)) + "u\n"

func _process(delta):
	if Input.is_action_pressed("leaderboard"):
		$Leaderboard.text = leaderboard
	else:
		$Leaderboard.text = ""
