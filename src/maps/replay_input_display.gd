class_name ReplayInputDisplay
extends HBoxContainer

const ACTIVE_BG := Palette.TEXT
const ACTIVE_BORDER := Palette.TEXT
const ACTIVE_FONT := Palette.BACKGROUND
const INACTIVE_BG := Palette.PANEL_FILL_SOFT
const INACTIVE_BORDER := Palette.BORDER
const INACTIVE_FONT := Palette.MUTED

var _input_states := {
	&"forward": false,
	&"back": false,
	&"left": false,
	&"right": false,
	&"shoot": false,
	&"ads": false,
	&"reload": false,
}

var _key_panels: Dictionary = { }
var _key_labels: Dictionary = { }
var _active_panel_style: StyleBoxFlat
var _inactive_panel_style: StyleBoxFlat

func _ready() -> void:
	_active_panel_style = _create_panel_style(ACTIVE_BG, ACTIVE_BORDER)
	_inactive_panel_style = _create_panel_style(INACTIVE_BG, INACTIVE_BORDER)

	_register_decorative_panel($"Movement/TopLeftSpacer")
	_register_key(&"forward", $"Movement/W")
	_register_decorative_panel($"Movement/TopRightSpacer")
	_register_key(&"back", $"Movement/S")
	_register_key(&"left", $"Movement/A")
	_register_key(&"right", $"Movement/D")
	_register_key(&"shoot", $"Combat/Shoot")
	_register_key(&"ads", $"Combat/Ads")
	_register_key(&"reload", $"Combat/Reload")

	reset()

func set_inputs(
		forward_input: bool,
		back_input: bool,
		left_input: bool,
		right_input: bool,
		shoot_input: bool,
		ads_input: bool,
		reload_input: bool,
) -> void:
	_input_states[&"forward"] = forward_input
	_input_states[&"back"] = back_input
	_input_states[&"left"] = left_input
	_input_states[&"right"] = right_input
	_input_states[&"shoot"] = shoot_input
	_input_states[&"ads"] = ads_input
	_input_states[&"reload"] = reload_input
	_apply_visual_state()

func reset() -> void:
	set_inputs(false, false, false, false, false, false, false)

func is_input_active(input_name: StringName) -> bool:
	return _input_states.get(input_name, false)

func _register_key(action_name: StringName, panel: PanelContainer) -> void:
	var label := panel.get_node_or_null("Label") as Label
	_key_panels[action_name] = panel
	_key_labels[action_name] = label

func _register_decorative_panel(panel: PanelContainer) -> void:
	if panel != null:
		panel.add_theme_stylebox_override("panel", _inactive_panel_style)

func _apply_visual_state() -> void:
	for action_name in _key_panels.keys():
		var panel := _key_panels[action_name] as PanelContainer
		var label := _key_labels.get(action_name) as Label
		var active := _input_states.get(action_name, false)

		if panel != null:
			panel.add_theme_stylebox_override("panel", _active_panel_style if active else _inactive_panel_style)
		if label != null:
			label.add_theme_color_override("font_color", ACTIVE_FONT if active else INACTIVE_FONT)

func _create_panel_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 5
	style.content_margin_top = 3
	style.content_margin_right = 5
	style.content_margin_bottom = 3
	return style
