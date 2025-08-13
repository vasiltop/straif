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
	focus_mode = Control.FOCUS_NONE

func _toggled(toggled_on: bool) -> void:
	if toggled_on:
		text = "Press a key..."
		for child in menu.keybinds.get_children():
			if child is Label: continue
			var c: InputButton = child
			if c.editing:
				c.button_pressed = false
				c.editing = false
	else:
		text = Settings.get_keybind_string(action_name)
	
	editing = toggled_on

func _input(event: InputEvent) -> void:
	if not editing or not event.is_pressed(): return

	if event is InputEventKey:
		var iek: InputEventKey = event
		Settings.change_action_to_event(action_name, iek)
		
	elif event is InputEventMouseButton:
		var iem: InputEventMouseButton = event
		Settings.change_action_to_event(action_name, iem)
		
	text = Settings.get_keybind_string(action_name)
	button_pressed = false
	editing = false
