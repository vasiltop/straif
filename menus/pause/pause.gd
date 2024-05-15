extends Control

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Buttons/Menu.pressed.connect(menu)
	$Buttons/Resume.pressed.connect(resume)

func menu():
	SceneManager.change_scene(SceneManager.SCENES.MAIN_MENU)

func resume():
	SceneManager.change_to_previous()
