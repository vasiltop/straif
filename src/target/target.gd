class_name Target extends Node3D 

@onready var map: Map = $"../.."

var health: float = 100

func _ready() -> void:
	tree_exited.connect(map.target_killed.emit)

func _process(_delta: float) -> void:
	var target_position :=  map.player.global_position if not map.is_watching_replay() else map.recorder.controller.global_position
	var current_position := global_position

	target_position.y = current_position.y

	look_at(target_position, Vector3.UP)
