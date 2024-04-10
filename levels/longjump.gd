extends Node

var url = "http://192.168.2.16:8000/1/leaderboard"
var leaderboard = ""

func _ready():
	var name = get_tree().current_scene.name
	url = "http://192.168.2.16:8000/" + name + "/leaderboard"
	
	$GetLeaderboard.request_completed.connect(handle_request)
	$GetLeaderboard.request(url)

func handle_request(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())

	for run in json:
		leaderboard += run.username + " | " + str(snapped(run.value / -1000, 0.01)) + "u\n"

func _process(delta):
	if Input.is_action_pressed("leaderboard"):
		$Leaderboard.text = leaderboard
	else:
		$Leaderboard.text = ""
