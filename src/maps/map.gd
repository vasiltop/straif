class_name Map extends Node

@onready var player: Player = $Player
@onready var end_zone: Area3D = $EndZone
@onready var start_zone: Area3D = $StartZone
@onready var target_container: Node = $Targets
@onready var start_pos: Vector3 = player.global_position

var timer: float = 0.0
var completed: bool = false
var running: bool = false

func _ready() -> void:
	restart()
	start_zone.body_exited.connect(_on_start_zone_exited)
	player.jumped.connect(_on_player_jump)

func _on_player_jump() -> void:
	if not completed: running = true

func _on_start_zone_exited(body: Node3D) -> void:
	if body is Player and not completed:
		running = true

func _process(delta: float) -> void:
	if not completed and _is_player_in_end_zone() and target_container.get_child_count() == 0:
		_win()
	
	if running:
		timer += delta
		player.set_timer(timer)

	if Input.is_action_just_pressed("restart"):
		restart()
	
func _is_player_in_end_zone() -> bool:
	var bodies := end_zone.get_overlapping_bodies()

	for body in bodies:
		if body is Player:
			return true

	return false

func _win() -> void:
	completed = true
	running = false

	print("Map finished in: %s" % timer)

func restart() -> void:
	player.global_position = start_pos
	timer = 0.0
	player.set_timer(timer)
	completed = false
	running = false
	player.velocity = Vector3.ZERO
