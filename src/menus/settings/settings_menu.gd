class_name SettingsMenu extends TabContainer

@onready var sens_label: Label = $Controls/Margin/V/Sensitivity/SensLabel
@onready var sens_slider: Slider = $Controls/Margin/V/Sensitivity/SliderInput
@onready var window_mode_input: OptionButton = $Display/Margin/V/WindowMode/Input
@onready var max_fps_input: SpinBox = $Display/Margin/V/MaxFps/Input
@onready var volume_slider: Slider = $Audio/Margin/V/Volume/Input
@onready var keybinds: HFlowContainer = $Controls/Margin/V/Keybinds
@onready var ads_sens_label: Label = $Controls/Margin/V/AdsSensitivity/SensLabel
@onready var ads_sens_slider: HSlider = $Controls/Margin/V/AdsSensitivity/SliderInput



func _ready() -> void:
	_set_init_values()

	sens_slider.value_changed.connect(_on_sens_slider_changed)
	ads_sens_slider.value_changed.connect(_on_ads_sens_slider_changed)
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	window_mode_input.item_selected.connect(_on_window_mode_changed)
	max_fps_input.value_changed.connect(_on_max_fps_changed)
	
	for action in Settings.get_custom_actions():
		var label := Label.new()
		label.text = action
		var inst := InputButton.new(self, action)
		
		keybinds.add_child(label)
		keybinds.add_child(inst)

func _set_init_values() -> void:
	var sens: float = Settings.value("Controls", "sensitivity")
	sens_slider.value = sens
	sens_label.text = str(sens)
	
	var ads_sens: float = Settings.value("Controls", "ads_sensitivity")
	ads_sens_slider.value = ads_sens
	ads_sens_label.text = str(ads_sens)

	window_mode_input.selected = Settings.value("Display", "mode")
	max_fps_input.value = Settings.value("Display", "max_fps")
	volume_slider.value = Settings.value("Audio", "master_volume")

func _on_volume_slider_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	Settings.update("Audio", "master_volume", value)

func _on_max_fps_changed(value: float) -> void:
	Engine.max_fps = int(value)
	Settings.update("Display", "max_fps", Engine.max_fps)

func _on_window_mode_changed(index: int) -> void:
	Settings.change_display_mode(index)
	Settings.update("Display", "mode", index)

func _on_sens_slider_changed(value: float) -> void:
	var new_sens: float = snapped(value, 0.01)
	sens_label.text = str(new_sens)
	Settings.update("Controls", "sensitivity", new_sens)

func _on_ads_sens_slider_changed(value: float) -> void:
	var new_sens: float = snapped(value, 0.01)
	ads_sens_label.text = str(new_sens)
	Settings.update("Controls", "ads_sensitivity", new_sens)
