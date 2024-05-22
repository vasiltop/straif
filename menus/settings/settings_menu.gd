extends Control

@onready var sens_input: LineEdit = $MarginContainer/Content/Margin/Settings/Sensitivity/Sens
@onready var fps_max_input: LineEdit = $MarginContainer/Content/Margin/Settings/MaxFps/MaxFps
@onready var screen_input: ItemList = $MarginContainer/Content/Margin/Settings/ScreenMode/ItemList
@onready var volume_input: HSlider = $MarginContainer/Content/Margin/Settings/Volume/HSlider

func _ready():
	$MarginContainer/Content/Navbar/HBoxContainer/Back.pressed.connect(SceneManager.change_to_previous)
	screen_input.item_selected.connect(change_screen_mode)
	volume_input.drag_ended.connect(update_volume)
	initialize_sens_input()
	initialize_screen_input()
	initialize_volume_input()
	initialize_fps_max_input()

func update_volume(changed: bool):
	if not changed: return
	
	Settings.volume = volume_input.value
	
func initialize_volume_input():
	volume_input.value = Settings.volume
	
func change_screen_mode(index: int):
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			
func initialize_sens_input():
	sens_input.text = str(Settings.sens)
	sens_input.text_changed.connect(update_sens)
	
func initialize_fps_max_input():
	fps_max_input.text = str(Engine.max_fps)
	fps_max_input.text_changed.connect(update_max_fps)
	
func update_max_fps(value: String):
	var fps = int(value)
	Engine.max_fps = fps
	
func initialize_screen_input():
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			screen_input.select(0)
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			screen_input.select(1)
		DisplayServer.WINDOW_MODE_WINDOWED:
			screen_input.select(2)
	
	
func update_sens(value: String):
	Settings.sens = float(value)
	
func _process(delta):
	pass
