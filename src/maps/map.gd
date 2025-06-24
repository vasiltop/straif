class_name Map extends Node

@onready var player: Player = $Player
@onready var end_zone: Area3D = $EndZone
@onready var start_zone: Area3D = $StartZone
@onready var target_container: Node = $Targets
@onready var start_pos: Vector3 = player.global_position
@onready var player_container: Node = $Players

const DummyPlayerScene := preload("res://src/dummy_player/dummy_player.tscn")

var timer: float = 0.0
var completed: bool = false
var running: bool = false

func _ready() -> void:
	restart()
	start_zone.body_exited.connect(_on_start_zone_exited)
	player.jumped.connect(_on_player_jump)
	Lobby.player_switched_map.connect(_on_player_switched_map)
	Lobby.player_diconnected.connect(_on_player_disconnected)
	Lobby.switched_map.rpc(Lobby.current_map.mid)

func _on_player_disconnected(pid: int) -> void:
	var p := find_player(pid)
	if p == null: return
	p.queue_free()

func _on_player_switched_map(pid: int, map: MapData) -> void:
	if Lobby.current_map.mid != map.mid: return

	if not player_exists(pid):
		Lobby.switched_map.rpc_id(pid, Lobby.current_map.mid)
		var inst: DummyPlayer = DummyPlayerScene.instantiate()
		player_container.add_child(inst)
		inst.name = str(pid)
		inst.pid = pid
		inst.global_position = start_pos
		inst.set_name_label("Player: %d" % pid)

@rpc("any_peer", "call_remote", "unreliable")
func moved(pos: Vector3) -> void:
	var p := find_player(multiplayer.get_remote_sender_id())
	if p == null: return

	p.global_position = pos

func find_player(pid: int) -> DummyPlayer:
	var players := player_container.get_children()

	for p in players:
		if p is DummyPlayer:
			var dp := p as DummyPlayer
			if dp.pid == pid:
				return dp

	return null

func player_exists(pid: int) -> bool:
	return find_player(pid) != null

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
	player.velocity = Vector3.ZERO
	timer = 0.0
	player.set_timer(timer)

	completed = false
	running = false
