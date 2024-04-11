extends Node3D

@onready var start_zone = $Level/StartZone
@onready var end_zone = $Level/EndZone
@onready var timer_label = $Timer
@onready var audio_player = $Music

var track1 = preload("res://sound/track1.wav")

var url = "http://192.168.2.16:8000/1/leaderboard"
var timer = 0
var completed = false
var started = false

var leaderboard = ""

func _ready():
	start_zone.get_node("Area3D").body_exited.connect(player_started)
	end_zone.get_node("Area3D").body_entered.connect(player_finished)
	var name = get_tree().current_scene.name
	url = "http://192.168.2.16:8000/" + name + "/leaderboard"
	
	$GetLeaderboard.request_completed.connect(handle_request)
	$GetLeaderboard.request(url)
	
func handle_request(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	for run in json:
		leaderboard += run.username + " | " + str(snapped(run.value / 1000, 0.01)) + "s\n"

func player_started(col):
	
	if !started:
		audio_player.stream = track1
		audio_player.play()
	started = true

func player_finished(col):
	
	if not completed:
		var body = JSON.stringify({
			"value": floor(timer * 1000)
		})
		var headers = ["Content-Type: application/json", "user_id: " + User.uuid]
		$PostLeaderboard.request(url, headers, HTTPClient.METHOD_POST, body)
	
	
	completed = true
	
func _process(delta):
	if Input.is_action_pressed("jump"):
		player_started({})
		
	if not completed and started:
		timer += delta
		timer_label.text = str(snapped(timer, 0.01)) + " s"
		
	if Input.is_action_pressed("leaderboard"):
		$Leaderboard.text = leaderboard
	else:
		$Leaderboard.text = ""
		
