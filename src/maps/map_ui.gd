class_name MapUi extends CanvasLayer

signal return_control_to_player

@onready var label: Label = $V/Label
@onready var slider: HSlider = $V/Slider
@onready var done: Button = $V/Done

func _ready() -> void:
	done.pressed.connect(func() -> void:
		return_control_to_player.emit()
	)

func set_frame(frame: int, total: int) -> void:
	label.text = "Frame: %d / %d" % [frame, total]
	slider.value = frame
	slider.max_value = total
