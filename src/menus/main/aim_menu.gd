class_name AimMenu extends Control

const AIM_TRAINER_SCENE := "res://src/maps/aim/aim_trainer.tscn"

@onready var gridshot_button: Button = $Margin/V/Cards/GridshotOption
@onready var flick_button: Button = $Margin/V/Cards/FlickOption
@onready var tracking_button: Button = $Margin/V/Cards/TrackingOption

func _ready() -> void:
	gridshot_button.pressed.connect(_play.bind("gridshot"))
	flick_button.pressed.connect(_play.bind("flick"))
	tracking_button.pressed.connect(_play.bind("tracking"))

func _play(scenario: String) -> void:
	Global.game_manager.current_aim_scenario = scenario
	get_tree().change_scene_to_file(AIM_TRAINER_SCENE)
