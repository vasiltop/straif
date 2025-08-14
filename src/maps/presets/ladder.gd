class_name Ladder extends Area3D

const CLIMB_SPEED := 300.0
@onready var player: Player = $"../../Player"
var touching_player: bool

func _ready() -> void:
	body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player:
				var p := body as Player
				if p.is_me():
					touching_player = true
	)
	
	body_exited.connect(
		func(body: Node3D) -> void:
			if body is Player:
				var p := body as Player
				if p.is_me():
					touching_player = false
	)
	
func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("climb") and touching_player:
		player.velocity.y = CLIMB_SPEED * delta
