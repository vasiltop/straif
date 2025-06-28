class_name SettingsMenu extends TabContainer

@onready var sens_input: LineEdit = $Controls/Margin/V/Sensitivity/TextInput
@onready var sens_slider: Slider = $Controls/Margin/V/Sensitivity/SliderInput
@onready var window_mode_input: OptionButton = $Display/Margin/V/WindowMode/Input
@onready var max_fps_input: SpinBox = $Display/Margin/V/MaxFps/Input
@onready var volume_slider: Slider = $Audio/Margin/V/Volume/Input

func _ready() -> void:
	var sens: float = Settings.value("Controls", "sensitivity")
	sens_input.text = str(sens)
	sens_slider.value = sens

	sens_slider.value_changed.connect(_on_sens_slider_changed)
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	sens_input.text_changed.connect(_on_sens_input_changed)
	window_mode_input.item_selected.connect(_on_window_mode_changed)
	max_fps_input.value_changed.connect(_on_max_fps_changed)

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
	sens_input.text = str(new_sens)
	Settings.update("Controls", "sensitivity", new_sens)

func _on_sens_input_changed(text: String) -> void:
	var digits_only := ""
	for c in text:
		if c.is_valid_int() || c == ".":
			digits_only += c

	if text != digits_only:
		sens_input.text = digits_only
	
	sens_slider.value = float(sens_input.text)
