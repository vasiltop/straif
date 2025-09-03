class_name MapUi extends CanvasLayer

signal return_control_to_player

@onready var map: Map = get_parent()
@onready var timer_label: Label = $UiContainer/BottomLeft/V/Timer
@onready var target_label: Label = $UiContainer/BottomLeft/V/EnemiesLeft
@onready var speed_label: Label = $UiContainer/BottomLeft/V/Speed
@onready var alt_speed_label: Label = $UiContainer/Middle/Speed
@onready var first_jump_speed_label: Label = $UiContainer/Middle/PreStrafeSpeed

@export var done_replay_btn: Button
@export var tick_label: Label
@export var replay_slider: HSlider
@export var replay_container: Control
@export var replay_v: VBoxContainer
@export var game_info: Container
@export var ammo_label: Label
@export var leaderboard: Container

func on_shot(mag_ammo: int, reserve_ammo := 0) -> void:
	ammo_label.text = "Ammo: %d / Inf" % [mag_ammo]

func _ready() -> void:
	done_replay_btn.pressed.connect(func() -> void:
		return_control_to_player.emit()
	)
	
	alt_speed_label.visible = Global.settings_manager.value("Display", "speed")

func set_frame(frame: int, total: int) -> void:
	tick_label.text = "Tick: %d / %d" % [frame + 1, total]
	replay_slider.value = frame
	replay_slider.max_value = total - 1

func set_replay_visible(value: bool) -> void:
	replay_container.visible = value
	replay_v.visible = value
	map.recorder.controller.visible = value

func is_replay_visible() -> bool:
	return replay_container.visible

func set_speed(value: float) -> void:
	speed_label.text = "%.2f u/s" % value
	alt_speed_label.text = speed_label.text
	
func requires_unlock() -> bool:
	return is_replay_visible() or game_info.visible

func _process(delta: float) -> void:
	if not is_replay_visible():
		set_speed(map.player.get_ups())
	
	if Input.is_action_just_pressed("ui_admin") and is_replay_visible():
		replay_v.visible = not replay_v.visible
		#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not v.visible else Input.MOUSE_MODE_VISIBLE
	
	if Input.is_action_just_pressed("restart") and is_replay_visible():
		map.recorder.set_frame(0)

func set_timer(value: float) -> void:
	timer_label.text = "Time: %.3fs" % value

func set_target_status(left: int, total: int) -> void:
	target_label.text = "Targets: %d/%d" % [left, total]
