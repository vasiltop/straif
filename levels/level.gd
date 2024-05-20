extends Node3D

@onready var start_zone = $Level/StartZone
@onready var end_zone = $Level/EndZone
@onready var timer_label = $LevelPack/Timer
@onready var audio_player = $LevelPack/Music
@onready var leaderboard = $LevelPack/Leaderboard
@onready var get_leaderboard_request = $LevelPack/GetLeaderboard
@onready var post_leaderboard_request = $LevelPack/PostLeaderboard
@onready var recorder = $LevelPack/Recorder
@onready var player = $LevelPack/Player

var leaderboard_entry = preload("res://levels/leaderboard/entry.tscn")
var track1 = preload("res://sound/track1.wav")
const run = preload("res://run.gd")
var url = Settings.base_url + "bhop/"
var timer = 0
var completed = false
var started = false
var map_name = ""
var player_is_on_first_checkpoint: bool = true

@export var kz_jump_style = false
@onready var start_pos: Vector3 = player.position 
@onready var checkpoint_pos: Vector3 = start_pos

func set_checkpoint_pos(pos: Vector3):
	checkpoint_pos = pos
	player_is_on_first_checkpoint = false

func _ready():
	player.kz_jump_style = kz_jump_style
	start_zone.get_node("Area3D").body_exited.connect(player_started)
	end_zone.get_node("Area3D").body_entered.connect(player_finished)
	map_name = get_tree().current_scene.name
	get_leaderboard_request.request_completed.connect(handle_leaderboard)
	get_leaderboard()
	post_leaderboard_request.request_completed.connect(test)

func test(result, response_code, headers, body):
	var json = body.get_string_from_utf8()
	
func get_leaderboard():
	
	var body = JSON.stringify({
			"map_name": map_name
	})

	var headers = ["Content-Type: application/json"]
	get_leaderboard_request.request(url + "leaderboard", headers, HTTPClient.METHOD_GET, body)

func handle_leaderboard(result, response_code, headers, body):
	if response_code != 200: return
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	for n in leaderboard.get_children():
		leaderboard.remove_child(n)
		n.queue_free()
		
	for run in json:
		var instance = leaderboard_entry.instantiate()
		instance.initialize(run.username, run.time_ms, int(run.user_id))
		leaderboard.add_child(instance)

func player_started(col):
	if completed or recorder.replaying or started: return

	started = true
	recorder.start()

func player_finished(col):

	if not completed:
		recorder.stop()
		var r = recorder.save(floor(timer * 1000))

		var body = r.to_bytes()
		var headers = ["Content-Type: application/json", "password: " + Settings.password, "auth_ticket: " + SteamClient.auth_ticket_hex]
		
		post_leaderboard_request.request_raw(url + "publish", headers, HTTPClient.METHOD_POST, body)
		
	completed = true

func update_timer_label():
	timer_label.text = str(snapped(timer, 0.01)) + " s"

func _process(delta):
	if Input.is_action_pressed("jump") or Input.is_action_just_pressed("jump"):
		player_started({})
	#print(completed, started)
	if not completed and started:
		timer += delta
		update_timer_label()
	
	if Input.is_action_just_pressed("leaderboard"):
		get_leaderboard()
	
	if Input.is_action_pressed("leaderboard"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		leaderboard.visible = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		leaderboard.visible = false
		
	if Input.is_action_just_pressed("restart"):
		
		if player_is_on_first_checkpoint or completed:
			timer = 0
			update_timer_label()
			started = false
			completed = false
			player_is_on_first_checkpoint = true
			player.position = start_pos
		else:
			player.position = checkpoint_pos

		player.velocity = Vector3.ZERO
