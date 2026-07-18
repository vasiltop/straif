class_name MultiplayerGame extends Node3D

const PlayerScene := preload("res://src/player/player.tscn")

@export var players: Node


func get_current_map_path() -> String:
	return Global.map_manager.get_full_map_path(
		Global.game_manager.current_pvp_mode, Global.game_manager.current_pvp_map
	)


func get_player(id: int) -> Player:
	for player: Player in get_players():
		if player.pid == id:
			return player

	return null


func get_players() -> Array[Node]:
	return players.get_children()
