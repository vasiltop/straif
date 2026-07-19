class_name InputButton extends Button

var menu: SettingsMenu
var editing: bool
var action_name: String

func _init(menu: SettingsMenu, action_name: String) -> void:
	self.action_name = action_name
	self.menu = menu

func _ready() -> void:
	toggle_mode = true
	theme_type_variation = &"GhostButton"
	custom_minimum_size = Vector2(140, 42)
	clip_text = true
	text = Global.settings_manager.get_keybind_string(action_name)
	focus_mode = Control.FOCUS_NONE

func _toggled(toggled_on: bool) -> void:
	if toggled_on:
		text = "PRESS A KEY"
		for c in _get_peer_buttons():
			if c == self:
				continue
			if c.editing:
				c.button_pressed = false
				c.editing = false
	else:
		text = Global.settings_manager.get_keybind_string(action_name)

	editing = toggled_on

func _get_peer_buttons() -> Array[InputButton]:
	var buttons: Array[InputButton] = []
	_collect_buttons(menu.keybinds, buttons)
	return buttons

func _collect_buttons(node: Node, buttons: Array[InputButton]) -> void:
	for child in node.get_children():
		if child is InputButton:
			buttons.append(child)
		else:
			_collect_buttons(child, buttons)

func _input(event: InputEvent) -> void:
	if not editing or not event.is_pressed():
		return

	if event is InputEventKey:
		var iek: InputEventKey = event
		Global.settings_manager.change_action_to_event(action_name, iek)
	elif event is InputEventMouseButton:
		var iem: InputEventMouseButton = event
		Global.settings_manager.change_action_to_event(action_name, iem)

	text = Global.settings_manager.get_keybind_string(action_name)
	button_pressed = false
	editing = false
	menu._mark_dirty()
