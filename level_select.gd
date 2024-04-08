extends Control

@onready var lj = $longjump
@onready var bh = $bhop

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	lj.pressed.connect(longjump)
	bh.pressed.connect(bhop)

func longjump():
	get_tree().change_scene_to_file("res://longjump.tscn")
	
func bhop():
	get_tree().change_scene_to_file("res://bhop.tscn")
	
func _process(delta):
	pass
