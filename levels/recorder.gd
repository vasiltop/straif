extends Node

var player = null
var camera = null

var level = null

var replay_index: int = 0

const run = preload("res://run.gd")

var current_run: run.Run = run.Run.new()
var recording = false
var replaying = false

var current_replay = null

func _ready():
	player = get_parent().get_node("Player")
	camera = player.get_node("Camera3D")
	level = get_parent()

func start():
	
	current_run = run.Run.new()
	recording = true

func stop():
	recording = false

func save(value):
	current_run.set_steam_id(SteamClient.steam_id)
	current_run.set_username(Steam.getPersonaName())
	current_run.set_value(value)
	current_run.set_map_name(get_tree().current_scene.name)
	
	return current_run

func replay(r):
	replaying = true
	recording = false
	current_replay = r

func replay_run():

	if replay_index >= len(current_replay) - 1:
		get_tree().reload_current_scene()
		return
	
	var front: run.Frame = current_replay[replay_index]
	
	player.position.x = front.get_position().get_x()
	player.position.y = front.get_position().get_y()
	player.position.z = front.get_position().get_z()
	
	player.rotation.y = front.get_playerRotation()
	player.get_node("Camera3D").rotation.x = front.get_cameraRotation()

	replay_index += 1
		
func _physics_process(delta):

	if recording:
		record_run()
	elif replaying:
		replay_run()

func record_run():
	if not recording: return
	
	var frame: run.Frame = current_run.add_frames()

	var position = frame.new_position()
	frame.set_playerRotation(player.rotation.y)
	frame.set_cameraRotation(camera.rotation.x)
	
	var pos = player.position
	position.set_x(pos.x)
	position.set_y(pos.y)
	position.set_z(pos.z)
