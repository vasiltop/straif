class_name Map extends Node

@onready var player: Player = $Player
@onready var end_zone: Area3D = $EndZone
@onready var start_zone: Area3D = $StartZone
@onready var target_container: Node = $Targets
@onready var start_pos: Vector3 = player.global_position
@onready var start_rotation: Vector3 = player.global_rotation
@onready var player_container: Node = $Players
@onready var target_spawns_container: Node = $TargetSpawns

const PlayerScene := preload("res://src/player/player.tscn")
const TargetScene := preload("res://src/target/target.tscn")

var timer: float = 0.0
var completed: bool = false
var running: bool = false
var recorder := Recorder.new()

func _ready() -> void:
	restart()
	add_child(recorder)
	start_zone.body_exited.connect(_on_start_zone_exited)
	player.jumped.connect(_on_player_jump)
	Lobby.player_switched_map.connect(_on_player_switched_map)
	Lobby.player_diconnected.connect(_on_player_disconnected)
	Lobby.player_left_map.connect(_on_player_disconnected)
	Lobby.switched_map.rpc(Lobby.current_map.mid)
	Lobby.replay_requested.connect(_on_replay_requested)
	player.setup(self)
	recorder.player_cam = player.camera

func _on_replay_requested(data: String) -> void:
	recorder.play_bytes(Marshalls.base64_to_raw(data))

func _on_player_disconnected(pid: int) -> void:
	var p := find_player(pid)
	if p == null: return
	p.queue_free()

func _on_player_switched_map(pid: int, map: MapData) -> void:
	print("Player %d switched to map %s" % [pid, map.name])
	if Lobby.current_map.mid != map.mid: return

	_received_switch.rpc_id(pid)
	if not player_exists(pid):
		spawn_player(pid)

@rpc("any_peer", "call_remote", "reliable")
func _received_switch() -> void:
	if not player_exists(multiplayer.get_remote_sender_id()):
		spawn_player(multiplayer.get_remote_sender_id())

func spawn_player(pid: int) -> void:
	var inst: Player = PlayerScene.instantiate()
	player_container.add_child(inst)
	inst.name = str(pid)
	inst.pid = pid
	inst.global_position = start_pos
	inst.set_name_label("Player: %d" % pid)

func _physics_process(_delta: float) -> void:
	if running:
		recorder.add_frame(player.global_position, player.global_rotation.y)

@rpc("any_peer", "call_remote", "unreliable")
func moved(pos: Vector3, y_rot: float) -> void:
	var p := find_player(multiplayer.get_remote_sender_id())
	if p == null: return

	p.global_position = pos
	p.global_rotation.y = y_rot

func find_player(pid: int) -> Player:
	var players := player_container.get_children()

	for p in players:
		if p is Player:
			var dp := p as Player 
			if dp.pid == pid:
				return dp

	return null

func get_players() -> Array[Player]:
	var ret: Array[Player]
	ret.assign(player_container.get_children())
	return ret

func get_target_spawns() -> Array[Node3D]:
	var ret: Array[Node3D]
	ret.assign(target_spawns_container.get_children())
	return ret

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
			var p: Player = body
			if not p.is_me(): continue

			return true

	return false

func _win() -> void:
	completed = true
	running = false

	var bytes := recorder.to_bytes()
	Http.publish_run(bytes, Lobby.current_map.name, int(timer * 1000))

func spawn_target(pos: Vector3) -> void:
	var inst: Target = TargetScene.instantiate()
	target_container.add_child(inst)
	inst.global_position = pos

func restart() -> void:
	player.global_position = start_pos
	player.global_rotation = start_rotation
	player.camera.global_rotation = start_rotation
	player.velocity = Vector3.ZERO
	player.weapon_handler.set_weapon(null)
	timer = 0.0
	player.set_timer(timer)

	completed = false
	running = false

	for node in get_tree().get_nodes_in_group("decal"):
		node.queue_free()

	for node in get_tree().get_nodes_in_group("weapon_pickup"):
		var wp: WeaponPickup = node
		wp.reset()

	for node in target_container.get_children():
		node.queue_free()

	for spawn in get_target_spawns():
		spawn_target(spawn.global_position)
	
	recorder.clear()
