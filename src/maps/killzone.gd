class_name Killzone extends Area3D

@onready var map: Map = $"../.."

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is not Player: return

	var p: Player = body
	if not p.is_me(): return

	map.restart(p)
