class_name SettingsMenu extends TabContainer

@onready var sens_label: Label = $Controls/Margin/V/Sensitivity/SensLabel
@onready var sens_slider: Slider = $Controls/Margin/V/Sensitivity/SliderInput
@onready var window_mode_input: OptionButton = $Display/Margin/V/WindowMode/Input
@onready var max_fps_input: SpinBox = $Display/Margin/V/MaxFps/Input
@onready var volume_slider: Slider = $Audio/Margin/V/Volume/Input

func _ready() -> void:
	_set_init_values()

	sens_slider.value_changed.connect(_on_sens_slider_changed)
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	window_mode_input.item_selected.connect(_on_window_mode_changed)
	max_fps_input.value_changed.connect(_on_max_fps_changed)

func _set_init_values() -> void:
	# sens
	var sens: float = Settings.value("Controls", "sensitivity")
	sens_slider.value = sens
	sens_label.text = str(sens)

	# display mode
	var index := 0

	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		index = 0
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		index = 1
	else:
		index = 2

	window_mode_input.selected = index

	#fps
	max_fps_input.value = Engine.max_fps

	#audio
	volume_slider.value = AudioServer.get_bus_volume_db(0)

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
