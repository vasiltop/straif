class_name InputButton extends Button

var menu: SettingsMenu
var editing: bool
var action_name: String

func _init(menu: SettingsMenu, action_name: String) -> void:
	self.action_name = action_name
	self.menu = menu

func _ready() -> void:
	toggle_mode = true
	text = Settings.get_keybind_string(action_name)

func _toggled(toggled_on: bool) -> void:
	if toggled_on:
		for child in menu.keybinds.get_children():
			if child is Label: continue
			var c: InputButton = child
			if c.editing:
				c.button_pressed = false
				c.editing = false
	
	editing = toggled_on

func _unhandled_input(event: InputEvent) -> void:
	var iek: InputEventKey = event
	if editing and event is InputEventKey and iek.is_pressed():
		Settings.change_keybind(action_name, iek.keycode)
		print("changing " + action_name + " to " + str(iek.keycode))
		button_pressed = false
		editing = false
		text = Settings.get_keybind_string(action_name)
