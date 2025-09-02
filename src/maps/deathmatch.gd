class_name Deathmatch extends Node

const PlayerScene := preload("res://src/player/player.tscn")
const Ak47 = preload("res://src/player/weapon/resources/ak47.tres")
const DmUiScene = preload("res://src/maps/dm_ui.tscn")

var loaded_map: Node3D = null
var dm_ui: DmUi = DmUiScene.instantiate()

@export var players: Node

func _ready() -> void:
	add_child(dm_ui)
	
	if not Global.is_sv():
		_send_info.rpc_id(1, Steam.getPersonaName())
	
	Global.game_manager.player_diconnected.connect(_on_player_disconnected)
	
	if Global.is_sv():
		var map_path := get_current_map_path()
		change_map.rpc(map_path)

func get_current_map_path() -> String:
	return Global.map_manager.get_full_map_path(Global.game_manager.current_pvp_mode, Global.game_manager.current_pvp_map)

@rpc("call_local", "authority", "reliable")
func change_map(path: String) -> void:
	Global.mp_print("Changing map to %s" % path)
	if loaded_map != null:
		loaded_map.queue_free()
		loaded_map = null

	var inst = load(path).instantiate()
	add_child(inst)
	loaded_map = inst

func _on_player_disconnected(id: int) -> void:
	for player in players.get_children():
		if player.pid == id:
			if Global.is_sv():
				dm_ui.log_player_event.rpc(player.get_node("Name").text, false)
			player.queue_free()
			return

func get_rand_spawn() -> Vector3:
	var spawns := loaded_map.get_node("Spawns").get_children()
	var spawn: Vector3 = spawns[randi_range(0, len(spawns) - 1)].global_position
	Global.mp_print("Generated random spawn pos: %s" % spawn)
	return spawn

@rpc("call_remote", "any_peer", "reliable")
func _send_info(steam_name: String) -> void:
	if not Global.is_sv(): return
	
	var sender := multiplayer.get_remote_sender_id()
	
	var map_path := get_current_map_path()
	change_map.rpc_id(sender, map_path)
		
	for player: Player in players.get_children():
		# we tell the new player where the current players are
		var weapon_index := Global.game_manager.get_weapon_index(player.weapon_handler.current_weapon)
		Global.mp_print("Sending weapon index of %d (%s) from player %d to %d" % [weapon_index, player.weapon_handler.current_weapon.name, player.pid, sender])
		_create_player.rpc_id(sender, player.pid, player.global_position, steam_name, weapon_index)

	_create_player.rpc(sender, get_rand_spawn(), steam_name, 1)
	dm_ui.log_player_event.rpc(steam_name, true)

@rpc("call_local", "authority", "reliable")
func _create_player(id: int, spawn_point: Vector3, steam_name: String, weapon_index: int) -> void:
	Global.mp_print("Spawning player %s" % steam_name)
	var inst := PlayerScene.instantiate()
	players.add_child(inst)
	inst.global_position = spawn_point
	inst.name = str(id)
	inst.pid = id
	inst.get_node("Name").text = steam_name
	
	if id == Global.id():
		inst.setup()
		inst.weapon_handler.shot.connect(dm_ui.on_shot)
		inst.damaged.connect(dm_ui.on_damaged)
		
	var weapon := Global.game_manager.get_weapon_from_index(weapon_index)
	inst.weapon_handler.set_weapon(weapon, id != Global.id())
		
	if Global.is_sv():
		inst.dead.connect(_on_player_death)

func new_map() -> void:
	var map := Global.map_manager.get_random_map(Global.game_manager.current_pvp_mode)

	# TODO: Add a new map
	#while map == Global.game_manager.current_pvp_map:
	#	map = Global.map_manager.get_random_map(Global.game_manager.current_pvp_mode)

	Global.mp_print("Changing map from %s to %s" % [Global.game_manager.current_pvp_map, map])
	Global.game_manager.current_pvp_map = map
	
	var path := get_current_map_path()
	change_map.rpc(path)
	
	for player: Player in players.get_children():
		player._update_state.rpc(get_rand_spawn(), 0, 0, 0)

func get_player(id: int) -> Player:
	for player: Player in players.get_children():
		if player.pid == id:
			return player
			
	return null
	
func get_players() -> Array[Node]:
	return players.get_children()

func _on_player_death(sender: int, id: int, weapon_name: String) -> void:
	Global.mp_print("Player %d has been killed." % id)
	dm_ui.log_kill.rpc(get_player(sender).player_name(), get_player(id).player_name(), weapon_name)
	get_player(id).ragdoll.rpc()
	await get_tree().create_timer(1.5).timeout
	get_player(id).respawn.rpc()
	get_player(id)._update_state.rpc(get_rand_spawn(), 0, 0, 0)
