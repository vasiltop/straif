class_name DummyPlayer extends Node3D

@onready var name_label: Label3D = $Name

var pid: int

func set_name_label(value: String) -> void:
	name_label.text = value
