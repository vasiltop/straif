class_name Elimination extends Node3D

const PlayerScene := preload("res://src/player/player.tscn")
const EliminationUiScene := preload("res://src/maps/elimination_ui.tscn")

const FREEZE_TIME := 4.0
const ROUND_TIME := 60.0
const ROUND_END_TIME := 5.0
const MATCH_END_TIME := 8.0
const WIN_SCORE := 5

enum Phase { WAITING, FREEZE, LIVE, ROUND_END, MATCH_END }

@export var players: Node

var loaded_map: Node3D = null
var elimination_ui = EliminationUiScene.instantiate()
var phase := Phase.WAITING
var time_left := 0.0
var team_scores := {1: 0, 2: 0}
var match_winner := 0
var pending_winner := 0
var teams := {}
var player_names := {}

var _next_tie_team := 1
var _last_displayed_seconds := -1


func _ready() -> void:
	add_child(elimination_ui)
	Global.game_manager.player_diconnected.connect(_on_player_disconnected)

	if Global.is_sv():
		change_map.rpc(get_current_map_path())
		_enter_waiting()
	else:
		_send_info.rpc_id(1, Steam.getPersonaName())


func _process(delta: float) -> void:
	if not Global.is_sv():
		return

	match phase:
		Phase.WAITING:
			if has_enough_players():
				_start_freeze()
		Phase.FREEZE:
			if not has_enough_players():
				_enter_waiting()
				return
			_advance_timer(delta)
			if time_left <= 0.0:
				_start_live()
		Phase.LIVE:
			_advance_timer(delta)
			if time_left <= 0.0:
				_finish_timeout()
		Phase.ROUND_END:
			_advance_timer(delta)
			if time_left <= 0.0:
				_finish_round_end()
		Phase.MATCH_END:
			if not has_enough_players():
				_enter_waiting(true)
				return
			_advance_timer(delta)
			if time_left <= 0.0:
				_reset_match()


func get_current_map_path() -> String:
	return Global.map_manager.get_full_map_path(
		Global.game_manager.current_pvp_mode,
		Global.game_manager.current_pvp_map
	)


@rpc("any_peer", "call_local", "reliable")
func change_map(path: String) -> void:
	if loaded_map != null:
		loaded_map.queue_free()

	loaded_map = load(path).instantiate()
	add_child(loaded_map)


@rpc("any_peer", "call_remote", "reliable")
func _send_info(steam_name: String) -> void:
	if not Global.is_sv():
		return

	var sender := multiplayer.get_remote_sender_id()
	var team := _assign_team()
	var spawn_point := _get_team_spawn(team, get_team_players(team).size())
	teams[sender] = team
	player_names[sender] = steam_name

	change_map.rpc_id(sender, get_current_map_path())
	for player: Player in get_players():
		_create_player.rpc_id(
			sender,
			player.pid,
			player.global_position,
			str(player_names.get(player.pid, player.player_name())),
			get_team(player.pid)
		)
		if player.is_dead:
			player.ragdoll.rpc_id(sender)
		_set_player_frozen.rpc_id(sender, player.pid, phase != Phase.LIVE)

	_create_player.rpc(sender, spawn_point, steam_name, team)
	get_player(sender).set_damage_enabled.rpc(phase == Phase.LIVE)
	_set_player_frozen.rpc(sender, phase != Phase.LIVE)

	if phase == Phase.WAITING and has_enough_players():
		_start_freeze()
	elif phase != Phase.LIVE and not has_enough_players():
		_enter_waiting()

	_broadcast_round_state()


func _assign_team() -> int:
	var team1_count := get_team_players(1).size()
	var team2_count := get_team_players(2).size()

	if team1_count == team2_count:
		var team := _next_tie_team
		_next_tie_team = 3 - _next_tie_team
		return team

	return 1 if team1_count < team2_count else 2


@rpc("any_peer", "call_local", "reliable")
func _create_player(
	id: int,
	spawn_point: Vector3,
	steam_name: String,
	team: int
) -> void:
	var inst := PlayerScene.instantiate()
	players.add_child(inst)
	inst.global_position = spawn_point
	inst.name = str(id)
	inst.pid = id
	inst.get_node("Name").text = steam_name
	inst.hardcore = true
	teams[id] = team
	player_names[id] = steam_name

	if id == Global.id():
		inst.setup()
		inst.weapon_handler.shot.connect(elimination_ui.on_shot)
		inst.damaged.connect(elimination_ui.on_damaged)

	inst.weapon_handler.set_weapon(
		Global.game_manager.get_weapon_from_index(1),
		id != Global.id()
	)

	if Global.is_sv():
		inst.dead.connect(_on_player_death)

	refresh_teammate_indicators()


func refresh_teammate_indicators() -> void:
	var local_team := get_team(Global.id())
	for player: Player in get_players():
		var show_indicator := (
			player.pid != Global.id()
			and get_team(player.pid) == local_team
			and not player.is_dead
		)
		player.set_teammate_indicator(show_indicator)


@rpc("any_peer", "call_local", "reliable")
func _sync_teammate_indicators() -> void:
	refresh_teammate_indicators()


func get_player(id: int) -> Player:
	for player: Player in get_players():
		if player.pid == id:
			return player

	return null


func get_players() -> Array[Node]:
	return players.get_children()


func get_team(id: int) -> int:
	return int(teams.get(id, 0))


func get_team_players(team: int) -> Array[Player]:
	var result: Array[Player] = []
	for player: Player in get_players():
		if get_team(player.pid) == team:
			result.append(player)

	return result


func get_alive_team_players(team: int) -> Array[Player]:
	var result: Array[Player] = []
	for player: Player in get_team_players(team):
		if not player.is_dead:
			result.append(player)

	return result


func has_enough_players() -> bool:
	return not get_team_players(1).is_empty() and not get_team_players(2).is_empty()


func _get_team_spawn(team: int, player_index: int) -> Vector3:
	var team_spawns: Node = loaded_map.get_node("Spawns/Team%d" % team)
	var spawn_points := team_spawns.get_children()
	var spawn: Marker3D = spawn_points[player_index % spawn_points.size()]
	return spawn.global_position


func _start_freeze() -> void:
	if not has_enough_players():
		_enter_waiting()
		return

	match_winner = 0
	_set_phase(Phase.FREEZE, FREEZE_TIME)

	for team in [1, 2]:
		var team_players := get_team_players(team)
		for index in range(team_players.size()):
			var player: Player = team_players[index]
			var spawn_point := _get_team_spawn(team, index)
			player.global_position = spawn_point
			player.velocity = Vector3.ZERO
			player.respawn.rpc(false)
			player._update_state.rpc(spawn_point, player.global_rotation.y, 0.0, 0.0)
			_set_player_frozen.rpc(player.pid, true)

	_sync_teammate_indicators.rpc()


func _start_live() -> void:
	_set_phase(Phase.LIVE, ROUND_TIME)
	for player: Player in get_players():
		player.set_damage_enabled.rpc(true)
		_set_player_frozen.rpc(player.pid, false)


func _start_match_end(winner: int) -> void:
	match_winner = winner
	_set_phase(Phase.MATCH_END, MATCH_END_TIME)
	for player: Player in get_players():
		player.set_damage_enabled.rpc(false)
		_set_player_frozen.rpc(player.pid, true)


func _reset_match() -> void:
	team_scores[1] = 0
	team_scores[2] = 0
	match_winner = 0
	_new_map()
	if has_enough_players():
		_start_freeze()
	else:
		_enter_waiting()


func _new_map() -> void:
	var mode := Global.game_manager.current_pvp_mode
	var current := Global.game_manager.current_pvp_map
	var map := Global.map_manager.get_random_map(mode)
	var attempts := 0
	while map == current and attempts < 8:
		map = Global.map_manager.get_random_map(mode)
		attempts += 1

	Global.game_manager.current_pvp_map = map
	change_map.rpc(get_current_map_path())


func _enter_waiting(reset_scores := false) -> void:
	if reset_scores:
		team_scores[1] = 0
		team_scores[2] = 0

	match_winner = 0
	_set_phase(Phase.WAITING, 0.0)
	for player: Player in get_players():
		player.set_damage_enabled.rpc(false)
		_set_player_frozen.rpc(player.pid, true)


func _advance_timer(delta: float) -> void:
	time_left = max(0.0, time_left - delta)
	var seconds := _displayed_seconds()
	if seconds != _last_displayed_seconds:
		_last_displayed_seconds = seconds
		_broadcast_round_state()


func _displayed_seconds() -> int:
	return max(0, int(ceil(time_left)))


func _set_phase(next_phase: int, duration: float) -> void:
	phase = next_phase
	time_left = duration
	_last_displayed_seconds = _displayed_seconds()
	_broadcast_round_state()


func _broadcast_round_state() -> void:
	_set_round_state.rpc(
		phase,
		time_left,
		team_scores[1],
		team_scores[2],
		match_winner
	)


@rpc("any_peer", "call_local", "reliable")
func _set_round_state(
	next_phase: int,
	next_time_left: float,
	score1: int,
	score2: int,
	winner: int
) -> void:
	phase = next_phase
	time_left = next_time_left
	team_scores[1] = score1
	team_scores[2] = score2
	match_winner = winner
	elimination_ui.update_round(
		phase,
		_displayed_seconds(),
		team_scores[1],
		team_scores[2],
		match_winner
	)
	elimination_ui.refresh_scoreboard()


@rpc("any_peer", "call_local", "reliable")
func _set_player_frozen(id: int, frozen: bool) -> void:
	var player := get_player(id)
	if player == null:
		return

	player.velocity = Vector3.ZERO
	player.can_move = not frozen and not player.is_dead
	player.weapon_handler.shooting_enabled = not frozen and not player.is_dead


func _on_player_death(sender: int, id: int, _weapon_name: String) -> void:
	if phase != Phase.LIVE:
		return

	var player := get_player(id)
	player.ragdoll.rpc()
	_set_player_frozen.rpc(id, true)
	_sync_teammate_indicators.rpc()
	_broadcast_round_state()
	_evaluate_live_round()


func _evaluate_live_round() -> void:
	if phase != Phase.LIVE:
		return

	var team1_alive := get_alive_team_players(1).size()
	var team2_alive := get_alive_team_players(2).size()
	if team1_alive == 0 or team2_alive == 0:
		var winner := 0
		if team1_alive > team2_alive:
			winner = 1
		elif team2_alive > team1_alive:
			winner = 2
		_finish_round(winner)


func _finish_timeout() -> void:
	var team1_alive := get_alive_team_players(1).size()
	var team2_alive := get_alive_team_players(2).size()
	var winner := 0
	if team1_alive > team2_alive:
		winner = 1
	elif team2_alive > team1_alive:
		winner = 2
	_finish_round(winner)


func _finish_round(winner: int) -> void:
	if phase != Phase.LIVE:
		return

	pending_winner = winner
	if winner != 0:
		team_scores[winner] += 1

	for player: Player in get_players():
		player.set_damage_enabled.rpc(false)

	_set_phase(Phase.ROUND_END, ROUND_END_TIME)


func _finish_round_end() -> void:
	var winner := pending_winner
	pending_winner = 0

	if winner != 0 and team_scores[winner] >= WIN_SCORE:
		_start_match_end(winner)
		return

	if has_enough_players():
		_start_freeze()
	else:
		_enter_waiting()


@rpc("any_peer", "call_local", "reliable")
func _remove_player(id: int) -> void:
	var player := get_player(id)
	if player != null:
		players.remove_child(player)
		player.queue_free()
	teams.erase(id)
	player_names.erase(id)
	refresh_teammate_indicators()


func _on_player_disconnected(id: int) -> void:
	if not Global.is_sv():
		_remove_player(id)
		return

	_remove_player.rpc(id)
	if phase == Phase.LIVE:
		_evaluate_live_round()
	elif not has_enough_players():
		_enter_waiting(phase == Phase.MATCH_END)
