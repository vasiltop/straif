extends Node3D

var data = null

func initialize(d):
	data = d
	get_node("Label").text = data.get_username() + " | " + str(float(data.get_value()) / 1000)
	get_node("Button").pressed.connect(on_replay_clicked)
	
func on_replay_clicked():
	if data == null: return

	get_parent().get_parent().get_node("Recorder").replay(data.get_frames())

