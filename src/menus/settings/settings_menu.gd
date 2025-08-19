class_name SettingsMenu extends TabContainer

@onready var sens_label: Label = $Controls/Margin/V/Sensitivity/SensLabel
@onready var sens_slider: Slider = $Controls/Margin/V/Sensitivity/SliderInput
@onready var window_mode_input: OptionButton = $Display/Margin/V/WindowMode/Input
@onready var max_fps_input: SpinBox = $Display/Margin/V/MaxFps/Input
@onready var volume_slider: Slider = $Audio/Margin/V/Volume/Input
@onready var keybinds: HFlowContainer = $Controls/Margin/V/Keybinds
@onready var ads_sens_label: Label = $Controls/Margin/V/AdsSensitivity/SensLabel
@onready var ads_sens_slider: HSlider = $Controls/Margin/V/AdsSensitivity/SliderInput
@onready var vsync_input: CheckBox = $Display/Margin/V/Vsync/Input
@onready var resolution_input: OptionButton = $Display/Margin/V/Resolution/Input
@onready var speed_label_input: CheckBox = $Display/Margin/V/SpeedLabel/Input

func _ready() -> void:
	_set_init_values()

	sens_slider.value_changed.connect(_on_sens_slider_changed)
	ads_sens_slider.value_changed.connect(_on_ads_sens_slider_changed)
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	window_mode_input.item_selected.connect(_on_window_mode_changed)
	resolution_input.item_selected.connect(_on_resolution_changed)
	max_fps_input.value_changed.connect(_on_max_fps_changed)
	vsync_input.toggled.connect(_on_vsync_changed)
	speed_label_input.toggled.connect(_on_speed_label_input_changed)
	
	for action in Global.settings_manager.get_custom_actions():
		var label := Label.new()
		label.text = action
		var inst := InputButton.new(self, action)
		
		keybinds.add_child(label)
		keybinds.add_child(inst)

func _on_vsync_changed(toggled_on: bool) -> void:
	DisplayServer.window_set_vsync_mode(Global.settings_manager.get_vsync_enum(toggled_on))
	Global.settings_manager.update("Display", "vsync", toggled_on)
	
func _on_speed_label_input_changed(toggled_on: bool) -> void:
	Global.settings_manager.update("Display", "speed", toggled_on)

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
	vsync_input.button_pressed = Global.settings_manager.value("Display", "vsync")
	speed_label_input.button_pressed = Global.settings_manager.value("Display", "speed")

	var res: String = Global.settings_manager.value("Display", "resolution")
	for i in resolution_input.item_count:
		var value := resolution_input.get_item_text(i)
		if value == res:
			resolution_input.select(i)
			break

func _on_volume_slider_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	Global.settings_manager.update("Audio", "master_volume", value)

func _on_max_fps_changed(value: float) -> void:
	Engine.max_fps = int(value)
	Global.settings_manager.update("Display", "max_fps", Engine.max_fps)

func _on_window_mode_changed(index: int) -> void:
	Global.settings_manager.change_display_mode(index)
	Global.settings_manager.update("Display", "mode", index)

func _on_resolution_changed(index: int) -> void:
	var value := resolution_input.get_item_text(index)
	Global.settings_manager.change_res(value)
	Global.settings_manager.update("Display", "resolution", value)

func _on_sens_slider_changed(value: float) -> void:
	var new_sens: float = snapped(value, 0.01)
	sens_label.text = str(new_sens)
	Global.settings_manager.update("Controls", "sensitivity", new_sens)

func _on_ads_sens_slider_changed(value: float) -> void:
	var new_sens: float = snapped(value, 0.01)
	ads_sens_label.text = str(new_sens)
	Global.settings_manager.update("Controls", "ads_sensitivity", new_sens)
