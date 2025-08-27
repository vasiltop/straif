class_name MapUi extends CanvasLayer

signal return_control_to_player

@onready var label: Label = $UiContainer/V/Label
@onready var slider: HSlider = $UiContainer/V/Slider
@onready var done: Button = $UiContainer/V/Done
@onready var v: VBoxContainer = $UiContainer/V
@onready var map: Map = get_parent()
@onready var start_time: Label = $UiContainer/StartTime
@onready var timer_label: Label = $UiContainer/BottomLeft/V/Timer
@onready var target_label: Label = $UiContainer/BottomLeft/V/EnemiesLeft

@onready var speed_label: Label = $UiContainer/BottomLeft/V/Speed
@onready var alt_speed_label: Label = $UiContainer/Middle/Speed
@onready var first_jump_speed_label: Label = $UiContainer/Middle/PreStrafeSpeed

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
	start_time.visible = not value
	v.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not value else Input.MOUSE_MODE_VISIBLE
	map.recorder.controller.visible = value

func is_replay_visible() -> bool:
	return v.visible

func set_start_time(time: float) -> void:
	if is_replay_visible(): return
	
	if time <= 0.0:
		start_time.visible = false
		return
	
	start_time.visible = true
	start_time.text = "Run Starting in %.1f" % time

func set_speed(value: float) -> void:
	speed_label.text = "%.2f u/s" % value
	alt_speed_label.text = speed_label.text

func _process(delta: float) -> void:
	if map.running:
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
