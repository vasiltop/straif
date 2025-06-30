class_name Target extends Node3D 

@onready var map: Map = $"../.."

var health: float = 100

func _ready() -> void:
	tree_exited.connect(map.target_killed.emit)
