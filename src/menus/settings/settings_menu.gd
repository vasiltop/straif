class_name SettingsMenu extends TabContainer

@export var sens_label: Label
@export var sens_slider: Slider
@export var window_mode_input: OptionButton
@export var max_fps_input: SpinBox
@export var volume_slider: Slider
@export var keybinds: HFlowContainer
@export var ads_sens_label: Label
@export var ads_sens_slider: HSlider
@export var vsync_input: Button
@export var resolution_input: OptionButton
@export var speed_label_input: Button
@export var world_record_announcements_input: Button
@export var save_settings_btn: Button

@onready var volume_label: Label = get_node_or_null("Audio/Margin/V/AudioRows/Volume/ValueLabel") as Label

func _ready() -> void:
	if Global.is_sv():
		return
	_set_init_values()

	sens_slider.value_changed.connect(_on_sens_slider_changed)
	ads_sens_slider.value_changed.connect(_on_ads_sens_slider_changed)
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	window_mode_input.item_selected.connect(_on_window_mode_changed)
	resolution_input.item_selected.connect(_on_resolution_changed)
	max_fps_input.value_changed.connect(_on_max_fps_changed)
	vsync_input.toggled.connect(_on_vsync_changed)
	speed_label_input.toggled.connect(_on_speed_label_input_changed)
	world_record_announcements_input.toggled.connect(_on_world_record_announcements_changed)
	save_settings_btn.pressed.connect(_on_save_pressed)
	save_settings_btn.disabled = true

	_build_section_tabs()

	for action in Global.settings_manager.get_custom_actions():
		keybinds.add_child(_make_keybind_row(action))

func _build_section_tabs() -> void:
	var host := get_parent().get_node("SectionTabs") as HBoxContainer
	var group := ButtonGroup.new()
	for i in get_tab_count():
		var idx := i
		var btn := Button.new()
		btn.text = get_tab_title(idx)
		btn.toggle_mode = true
		btn.button_group = group
		btn.theme_type_variation = &"Segment"
		btn.focus_mode = Control.FOCUS_NONE
		btn.button_pressed = idx == current_tab
		btn.pressed.connect(func() -> void: current_tab = idx)
		host.add_child(btn)

func _mark_dirty() -> void:
	save_settings_btn.disabled = false

func _on_save_pressed() -> void:
	Global.settings_manager.save()
	save_settings_btn.disabled = true

func _make_keybind_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(300, 48)
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = action
	label.theme_type_variation = &"Body"
	label.custom_minimum_size = Vector2(144, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var input := InputButton.new(self, action)

	row.add_child(label)
	row.add_child(input)
	return row

func _on_vsync_changed(toggled_on: bool) -> void:
	DisplayServer.window_set_vsync_mode(Global.settings_manager.get_vsync_enum(toggled_on))
	Global.settings_manager.update("Display", "vsync", toggled_on)
	_mark_dirty()

func _on_speed_label_input_changed(toggled_on: bool) -> void:
	Global.settings_manager.update("Display", "speed", toggled_on)
	_mark_dirty()

func _on_world_record_announcements_changed(toggled_on: bool) -> void:
	Global.settings_manager.update("Game", "world_record_announcements", toggled_on)
	Global.server_bridge.set_world_record_announcements_enabled(toggled_on)
	_mark_dirty()

func _set_init_values() -> void:
	var sens: float = Global.settings_manager.value("Controls", "sensitivity")
	sens_slider.value = sens
	sens_label.text = str(sens)

	var ads_sens: float = Global.settings_manager.value("Controls", "ads_sensitivity")
	ads_sens_slider.value = ads_sens
	ads_sens_label.text = str(ads_sens)

	window_mode_input.selected = Global.settings_manager.value("Display", "mode")
	max_fps_input.value = Global.settings_manager.value("Display", "max_fps")
	volume_slider.value = Global.settings_manager.value("Audio", "master_volume")
	_update_volume_label(volume_slider.value)
	vsync_input.button_pressed = Global.settings_manager.value("Display", "vsync")
	speed_label_input.button_pressed = Global.settings_manager.value("Display", "speed")
	var world_record_enabled: bool = Global.settings_manager.value("Game", "world_record_announcements")
	world_record_announcements_input.button_pressed = world_record_enabled

	var res: String = Global.settings_manager.value("Display", "resolution")
	for i in resolution_input.item_count:
		var value := resolution_input.get_item_text(i)
		if value == res:
			resolution_input.select(i)
			break

func _on_volume_slider_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	_update_volume_label(value)
	Global.settings_manager.update("Audio", "master_volume", value)
	_mark_dirty()

func _update_volume_label(value: float) -> void:
	if volume_label == null:
		return
	var db := snapped(value, 0.1)
	var prefix := "+" if db > 0.0 else ""
	volume_label.text = prefix + str(db) + " DB"

func _on_max_fps_changed(value: float) -> void:
	Engine.max_fps = int(value)
	Global.settings_manager.update("Display", "max_fps", Engine.max_fps)
	_mark_dirty()

func _on_window_mode_changed(index: int) -> void:
	Global.settings_manager.change_display_mode(index)
	Global.settings_manager.update("Display", "mode", index)
	_mark_dirty()

func _on_resolution_changed(index: int) -> void:
	var value := resolution_input.get_item_text(index)
	Global.settings_manager.change_res(value)
	Global.settings_manager.update("Display", "resolution", value)
	_mark_dirty()

func _on_sens_slider_changed(value: float) -> void:
	var new_sens: float = snapped(value, 0.01)
	sens_label.text = str(new_sens)
	Global.settings_manager.update("Controls", "sensitivity", new_sens)
	_mark_dirty()

func _on_ads_sens_slider_changed(value: float) -> void:
	var new_sens: float = snapped(value, 0.01)
	ads_sens_label.text = str(new_sens)
	Global.settings_manager.update("Controls", "ads_sensitivity", new_sens)
	_mark_dirty()
