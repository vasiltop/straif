extends Control

@onready var command = $Container/Command

var time_alive = 0
var prev_commands = []
const MAX_COMMAND_LABEL_LENGTH = 25

func _ready():
	pass

func _process(delta):
	
	if !visible: 
		time_alive = 0
		return

	time_alive += delta

	if Input.is_action_just_pressed("console") and time_alive > 0.1:
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if command.has_focus() and Input.is_action_just_pressed("submit"):
		prev_commands.append(command.text)
		parse_command(command.text)
		command.text = ""

func parse_command(command):
	var split = command.split(' ')
	match first_word(command):
		"fullscreen", "f":
			Settings.toggle_fullscreen()
			output("Fullscreen toggled.")
		"sens", "sensitivity":
			Settings.sens = float(split[1])
			output("Sens changed to " + split[1] + ".")
		"map":
			if len(split) == 1:
				output("Current maps: dawn, fog,
						longjump, rookie.")
			else:
				var name = split[1]
				get_tree().change_scene_to_file("res://levels/" + name + ".tscn")
		"logout":
			DirAccess.remove_absolute(Settings.save_file)
			get_tree().change_scene_to_file("res://menus/account/account.tscn")
		"quit":
			get_tree().quit()
		"baseurl":
			Settings.base_url = split[1]
		"help":
			output("Available Commands:
						fullscreen | f
						sensitivity | sens <value>
						map <name> | map
						logout
						quit
						")

func first_word(str):
	return str.split(' ')[0]

func output(str):
	$Container/Output.text = str
