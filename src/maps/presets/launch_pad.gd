class_name LaunchPad extends Area3D

@export var launch_force: float

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body is Player: return

	var p: Player = body
	p.velocity.y = launch_force
