class_name MapUi extends CanvasLayer

signal return_control_to_player

@onready var label: Label = $UiContainer/V/Label
@onready var slider: HSlider = $UiContainer/V/Slider
@onready var done: Button = $UiContainer/V/Done
@onready var v: VBoxContainer = $UiContainer/V
@onready var map: Map = get_parent()
@onready var timer_label: Label = $UiContainer/BottomLeft/V/Timer
@onready var target_label: Label = $UiContainer/BottomLeft/V/EnemiesLeft
@onready var speed_label: Label = $UiContainer/BottomLeft/V/Speed
@onready var alt_speed_label: Label = $UiContainer/Middle/Speed
@onready var first_jump_speed_label: Label = $UiContainer/Middle/PreStrafeSpeed

@export var ammo_label: Label

func on_shot(mag_ammo: int, reserve_ammo: int) -> void:
	ammo_label.text = "Ammo: %d / %d" % [mag_ammo, reserve_ammo]

func _ready() -> void:
	done.pressed.connect(func() -> void:
		return_control_to_player.emit()
	)
	
	alt_speed_label.visible = Global.settings_manager.value("Display", "speed")

func set_frame(frame: int, total: int) -> void:
	label.text = "Tick: %d / %d" % [frame, total]
	slider.value = frame
	slider.max_value = total

func set_replay_visible(value: bool) -> void:
	v.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not value else Input.MOUSE_MODE_VISIBLE
	map.recorder.controller.visible = value

func is_replay_visible() -> bool:
	return v.visible

func set_speed(value: float) -> void:
	speed_label.text = "%.2f u/s" % value
	alt_speed_label.text = speed_label.text

func _process(delta: float) -> void:
	if not is_replay_visible():
		set_speed(map.player.get_ups())
	
	if Input.is_action_just_pressed("ui_admin") and is_replay_visible():
		visible = not visible
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not visible else Input.MOUSE_MODE_VISIBLE
	
	if Input.is_action_just_pressed("restart") and is_replay_visible():
		map.recorder.set_frame(0)

func set_timer(value: float) -> void:
	timer_label.text = "Time: %.3fs" % value

func set_target_status(left: int, total: int) -> void:
	target_label.text = "Targets: %d/%d" % [left, total]
