extends Node3D

@onready var start_zone = $Level/StartZone
@onready var end_zone = $Level/EndZone
@onready var timer_label = $Timer
@onready var audio_player = $Music

@onready var player = $Player
@onready var camera = player.get_node("Camera3D")

var track1 = preload("res://sound/track1.wav")

var url = Settings.base_url + "bhop/"
var timer = 0
var completed = false
var started = false
var map_name = ""
var leaderboard = "Could not connect to server. Check if their is a newer game version, or the server is down."

const run = preload("res://run.gd")
var current_run: run.Run = run.Run.new()

var replaying: bool = false
var replay_index: int = 0

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
		var body = JSON.stringify({
				"map_name": map_name,
				"user_id": SteamClient.steam_id,
				"time": floor(timer * 1000),
				"auth_ticket": SteamClient.auth_ticket_hex,
				"username": Steam.getPersonaName()
		})
		
		var headers = ["Content-Type: application/json", "password: " + Settings.password]
		
		$PostLeaderboard.request(url + "publish", headers, HTTPClient.METHOD_POST, body)
		
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
		

func _physics_process(delta):
	if replaying:
		if replay_index >= len(Settings.previous_run) - 1:
			get_tree().reload_current_scene()
			return
			
		var front: run.Frame = Settings.previous_run[replay_index]
		
		player.position.x = front.get_position().get_x()
		player.position.y = front.get_position().get_y()
		player.position.z = front.get_position().get_z()
		
		player.rotation.x = front.get_playerRotation().get_x()
		player.rotation.y = front.get_playerRotation().get_y()
		player.rotation.z = front.get_playerRotation().get_z()

		player.get_node("Camera3D").rotation.x = front.get_cameraRotation().get_x()
		player.get_node("Camera3D").rotation.y = front.get_cameraRotation().get_y()
		player.get_node("Camera3D").rotation.z = front.get_cameraRotation().get_z()
		
		replay_index += 1

	else:
		record_run()
	

func record_run():
	if not started or completed: return
	
	var frame: run.Frame = current_run.add_frames()

	var position = frame.new_position()
	var player_rotation = frame.new_playerRotation()
	var camera_rotation = frame.new_cameraRotation()
	
	var pos = player.position
	position.set_x(pos.x)
	position.set_y(pos.y)
	position.set_z(pos.z)
	
	player_rotation.set_y(player.rotation.y)
	camera_rotation.set_x(camera.rotation.x)
