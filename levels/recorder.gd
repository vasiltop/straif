extends Node

var player = null
var camera = null

var level = null

var replay_index: int = 0
const run = preload("res://run.gd")

func _ready():
	player = get_parent().get_node("Player")
	camera = player.get_node("Camera3D")
	level = get_parent()

func replay():
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
		
func _physics_process(delta):
	if level.replaying:
		replay()
	else:
		record_run()

func record_run():
	if not level.started or level.completed: return
	
	var frame: run.Frame = level.current_run.add_frames()

	var position = frame.new_position()
	var player_rotation = frame.new_playerRotation()
	var camera_rotation = frame.new_cameraRotation()
	
	var pos = player.position
	position.set_x(pos.x)
	position.set_y(pos.y)
	position.set_z(pos.z)
	
	player_rotation.set_y(player.rotation.y)
	camera_rotation.set_x(camera.rotation.x)
