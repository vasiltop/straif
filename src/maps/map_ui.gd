class_name MapUi extends CanvasLayer

signal return_control_to_player

@onready var label: Label = $V/Label
@onready var slider: HSlider = $V/Slider
@onready var done: Button = $V/Done
@onready var v: VBoxContainer = $V
@onready var map: Map = get_parent()
@onready var speed: Label = $V/Speed

func _ready() -> void:
	done.pressed.connect(func() -> void:
		return_control_to_player.emit()
	)

func set_frame(frame: int, total: int) -> void:
	label.text = "Tick: %d / %d" % [frame, total]
	slider.value = frame
	slider.max_value = total

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_admin"):
		v.visible = not v.visible
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if not v.visible else Input.MOUSE_MODE_VISIBLE
	
	if Input.is_action_just_pressed("restart"):
		map.recorder.set_frame(0)
		
	speed.text = "Speed: %.2f u/s" % map.recorder.speed
