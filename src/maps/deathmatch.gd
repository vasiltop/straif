class_name Deathmatch extends Node

@onready var spawn: Marker3D = $Spawns/Spawn
@onready var players: Node = $Players

const PlayerScene := preload("res://src/player/player.tscn")
const Ak47 = preload("res://src/player/weapon/resources/ak47.tres")

func _ready() -> void:
	if not Global.is_sv():
		_send_info.rpc_id(1, Steam.getPersonaName())
	
	Global.game_manager.player_diconnected.connect(_on_player_disconnected)

func _on_player_disconnected(id: int) -> void:
	for player in players.get_children():
		if player.pid == id: # TODO: Make the bullet holes not hit the player
			player.queue_free()

@rpc("call_remote", "any_peer", "reliable")
func _send_info(steam_name: String) -> void:
	if not Global.is_sv(): return
	
	var sender := multiplayer.get_remote_sender_id()
	
	for player: Player in players.get_children():
		Global.mp_print("Telling %d to create %d" % [sender, player.pid])
		_create_player.rpc_id(sender, player.pid, spawn.global_position, steam_name)
		
	_create_player.rpc(sender, spawn.global_position, steam_name)

@rpc("call_local", "authority", "reliable")
func _create_player(id: int, spawn_point: Vector3, steam_name: String) -> void:
	var inst := PlayerScene.instantiate()
	players.add_child(inst)
	inst.global_position = spawn_point
	inst.name = str(id)
	inst.pid = id
	inst.get_node("Name").text = steam_name
	inst.weapon_handler.set_weapon(Ak47, id != Global.id())
	
	if id == Global.id():
		inst.setup()
		
	if Global.is_sv():
		inst.dead.connect(_on_player_death)

func get_player(id: int) -> Player:
	for player: Player in players.get_children():
		if player.pid == id:
			return player
			
	return null

func _on_player_death(id: int) -> void:
	Global.mp_print("Player %d has been killed." % id)
	get_player(id).ragdoll.rpc()
	await get_tree().create_timer(1.5).timeout
	get_player(id).respawn.rpc()
	get_player(id)._update_state.rpc(spawn.global_position, 0, 0, 0)
