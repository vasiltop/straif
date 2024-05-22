extends Node

var url = Settings.base_url + "longjump/leaderboard"
var leaderboard = "Could not connect to server."
const run = preload("res://run.gd")
var leaderboard_entry = preload("res://levels/leaderboard/entry.tscn")

func _ready():
	$GetLeaderboard.request_completed.connect(handle_request)
	$GetLeaderboard.request(url)

func handle_request(result, response_code, headers, body):
	if response_code != 200: return
	
	var json = JSON.parse_string(body.get_string_from_utf8())	
	
	for n in $Leaderboard.get_children():
		$Leaderboard.remove_child(n)
		n.queue_free() 
			
	for jump in json:
		var instance = leaderboard_entry.instantiate()
		instance.initialize(jump.username, jump.length, int(jump.user_id), "", true)
		$Leaderboard.add_child(instance)

func _process(delta):
	
	if Input.is_action_just_pressed("leaderboard"):
		$GetLeaderboard.request(url)
		
	if Input.is_action_pressed("leaderboard"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		$Leaderboard.visible = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		$Leaderboard.visible = false
