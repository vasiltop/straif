extends Node3D

@onready var start_zone = $Level/StartZone
@onready var end_zone = $Level/EndZone
@onready var timer_label = $Timer
@onready var audio_player = $Music

var track1 = preload("res://sound/track1.wav")
const run = preload("res://run.gd")
var url = Settings.base_url + "bhop/"
var timer = 0
var completed = false
var started = false
var map_name = ""
var leaderboard = "Could not connect to server. Check if their is a newer game version, or the server is down."

var replaying: bool = false

var current_run: run.Run = run.Run.new()

func _ready():
	start_zone.get_node("Area3D").body_exited.connect(player_started)
	end_zone.get_node("Area3D").body_entered.connect(player_finished)
	map_name = get_tree().current_scene.name
	
	get_leaderboard()
	$PostLeaderboard.request_completed.connect(test)

func test(result, response_code, headers, body):
	var json = body.get_string_from_utf8()
	print(json)
	
func get_leaderboard():
	$GetLeaderboard.request_completed.connect(handle_leaderboard)
	var body = JSON.stringify({
			"map_name": map_name
	})

	var headers = ["Content-Type: application/json"]
	$GetLeaderboard.request(url + "leaderboard", headers, HTTPClient.METHOD_GET, body)

func handle_leaderboard(result, response_code, headers, body):
	
	if response_code != 200: return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	leaderboard = ""
	
	for run in json:
		leaderboard += run.username + " | " + str(snapped(run.time_ms / 1000, 0.01)) + "s\n"

func player_started(col):
	started = true

func player_finished(col):

	if not completed:
		current_run.set_steam_id(SteamClient.steam_id)
		current_run.set_username(Steam.getPersonaName())
		current_run.set_value(floor(timer * 1000))
		current_run.set_map_name(map_name)

		var body = current_run.to_bytes()
		var headers = ["Content-Type: application/json", "password: " + Settings.password, "auth_ticket: " + SteamClient.auth_ticket_hex]
		
		$PostLeaderboard.request_raw(url + "publish", headers, HTTPClient.METHOD_POST, body)
		
		Settings.previous_run = current_run.get_frames()
		current_run.clear_frames()
		
	completed = true
	

func _process(delta):
	if Input.is_action_pressed("jump") or Input.is_action_just_pressed("jump"):
		player_started({})
		
	if not completed and started:
		timer += delta
		timer_label.text = str(snapped(timer, 0.01)) + " s"
		
	if Input.is_action_pressed("leaderboard"):
		$Leaderboard.text = leaderboard
	else:
		$Leaderboard.text = ""
		
	if Input.is_action_just_pressed("replay"):
		
		$Player.movement_paused = true
		replaying = true
