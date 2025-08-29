class_name Deathmatch extends Node

@export var spawns: Node
@export var players: Node
@onready var dm_ui: DmUi = DmUiScene.instantiate()

const PlayerScene := preload("res://src/player/player.tscn")
const Ak47 = preload("res://src/player/weapon/resources/ak47.tres")
const DmUiScene = preload("res://src/maps/dm_ui.tscn")

func _ready() -> void:
	add_child(dm_ui)
	
	if not Global.is_sv():
		_send_info.rpc_id(1, Steam.getPersonaName())
	
	Global.game_manager.player_diconnected.connect(_on_player_disconnected)

func _on_player_disconnected(id: int) -> void:
	for player in players.get_children():
		if player.pid == id: # TODO: Make the bullet holes not hit the player
			player.queue_free()

func get_rand_spawn() -> Vector3:
	var spawns := spawns.get_children()
	return spawns[randi_range(0, len(spawns) - 1)].global_position

@rpc("call_remote", "any_peer", "reliable")
func _send_info(steam_name: String) -> void:
	if not Global.is_sv(): return
	
	var sender := multiplayer.get_remote_sender_id()
	
	for player: Player in players.get_children():
		# we tell the new player where the current players are
		var weapon_index := Global.game_manager.get_weapon_index(player.weapon_handler.current_weapon)
		Global.mp_print("Sending weapon index of %d (%s) from player %d to %d" % [weapon_index, player.weapon_handler.current_weapon.name, player.pid, sender])
		_create_player.rpc_id(sender, player.pid, player.global_position, steam_name, weapon_index)
		
	_create_player.rpc(sender, get_rand_spawn(), steam_name, 2)

@rpc("call_local", "authority", "reliable")
func _create_player(id: int, spawn_point: Vector3, steam_name: String, weapon_index: int) -> void:
	var inst := PlayerScene.instantiate()
	players.add_child(inst)
	inst.global_position = spawn_point
	inst.name = str(id)
	inst.pid = id
	inst.get_node("Name").text = steam_name
	
	if id == Global.id():
		inst.setup()
		inst.weapon_handler.shot.connect(dm_ui.on_shot)
		
	var weapon := Global.game_manager.get_weapon_from_index(weapon_index)
	inst.weapon_handler.set_weapon(weapon, id != Global.id())
		
	if Global.is_sv():
		inst.dead.connect(_on_player_death)

func get_player(id: int) -> Player:
	for player: Player in players.get_children():
		if player.pid == id:
			return player
			
	return null
	
func get_players() -> Array[Node]:
	return players.get_children()

func _on_player_death(sender: int, id: int) -> void:
	Global.mp_print("Player %d has been killed." % id)
	dm_ui.log_kill.rpc(get_player(sender).player_name(), get_player(sender).player_name())
	get_player(id).ragdoll.rpc()
	await get_tree().create_timer(1.5).timeout
	get_player(id).respawn.rpc()
	get_player(id)._update_state.rpc(get_rand_spawn(), 0, 0, 0)
