class_name EliminationUi extends CanvasLayer

@export var scoreboard_panel: PanelContainer
@export var team1_rows: VBoxContainer
@export var team2_rows: VBoxContainer
@export var phase_label: Label
@export var timer_label: Label
@export var team1_score_label: Label
@export var team2_score_label: Label
@export var scoreboard_score_label: Label
@export var ammo_label: Label
@export var health_label: Label
@export var spectator_panel: PanelContainer
@export var spectator_label: Label
@export var match_end_panel: PanelContainer
@export var match_end_label: Label

const PHASE_WAITING := 0
const PHASE_FREEZE := 1
const PHASE_LIVE := 2
const PHASE_MATCH_END := 3

var spectator_target_id := 0
var spectator_index := -1
var was_locally_dead := false
var scoreboard_signature := ""


func _ready() -> void:
	scoreboard_panel.visible = false
	spectator_panel.visible = false
	match_end_panel.visible = false
	refresh_scoreboard()


func _process(_delta: float) -> void:
	if Global.is_sv():
		return

	var wants_scoreboard := Input.is_action_pressed("leaderboard")
	if scoreboard_panel.visible != wants_scoreboard:
		scoreboard_panel.visible = wants_scoreboard
		if wants_scoreboard:
			refresh_scoreboard()
	elif wants_scoreboard:
		refresh_scoreboard()

	_update_spectator()


func update_round(phase: int, seconds: int, score1: int, score2: int, winner: int) -> void:
	phase_label.text = _phase_text(phase)
	timer_label.text = "%02d:%02d" % [int(seconds / 60), seconds % 60]
	team1_score_label.text = str(score1)
	team2_score_label.text = str(score2)
	scoreboard_score_label.text = "Team 1: %d - Team 2: %d" % [score1, score2]

	var match_over := phase == PHASE_MATCH_END
	match_end_panel.visible = match_over
	if match_over:
		match_end_label.text = "Team %d wins the match" % winner


func refresh_scoreboard() -> void:
	var team1_players := _players_on_team(1)
	var team2_players := _players_on_team(2)
	var next_signature := _team_signature(team1_players) + "|" + _team_signature(team2_players)
	if next_signature == scoreboard_signature:
		return
	scoreboard_signature = next_signature

	_clear_rows(team1_rows)
	_clear_rows(team2_rows)

	if team1_players.is_empty():
		_add_waiting_row(team1_rows)
	else:
		for player: Player in team1_players:
			_add_player_row(team1_rows, player)

	if team2_players.is_empty():
		_add_waiting_row(team2_rows)
	else:
		for player: Player in team2_players:
			_add_player_row(team2_rows, player)


func on_shot(mag_ammo: int, reserve_ammo: int) -> void:
	ammo_label.text = "Ammo: %d / Inf" % mag_ammo


func on_damaged(health: float) -> void:
	health_label.text = "Health: %d" % int(maxf(0.0, health))


func _phase_text(phase: int) -> String:
	match phase:
		PHASE_WAITING:
			return "Waiting for players"
		PHASE_FREEZE:
			return "Freeze time"
		PHASE_LIVE:
			return "Round live"
		PHASE_MATCH_END:
			return "Match over"
	return "Waiting for players"


func _clear_rows(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _add_waiting_row(container: VBoxContainer) -> void:
	var waiting := Label.new()
	waiting.text = "Waiting for player..."
	waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(waiting)


func _add_player_row(container: VBoxContainer, player: Player) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var player_name := Label.new()
	player_name.text = player.player_name()
	player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name.clip_text = true

	var state := Label.new()
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.custom_minimum_size = Vector2(52.0, 0.0)

	if player.is_dead:
		state.text = "Dead"
	else:
		state.text = "Alive"

	row.add_child(player_name)
	row.add_child(state)
	container.add_child(row)


func _team_signature(players: Array[Player]) -> String:
	var signature := ""
	for player: Player in players:
		signature += "%d:%s:%s;" % [player.pid, player.player_name(), player.is_dead]
	return signature


func _update_spectator() -> void:
	var local_player := _get_player(Global.id())
	if local_player == null:
		was_locally_dead = false
		_reset_spectator()
		return

	if not local_player.is_dead:
		if was_locally_dead:
			local_player.camera.make_current()
		was_locally_dead = false
		_reset_spectator()
		return

	if not was_locally_dead:
		was_locally_dead = true
		spectator_target_id = 0
		spectator_index = -1

	var teammates := _living_teammates(_team_for_player(local_player))
	if teammates.is_empty():
		_show_no_teammates(local_player)
		return

	var current_index := _find_player_index(teammates, spectator_target_id)
	if current_index == -1:
		var next_index := 0 if spectator_index < 0 else min(spectator_index, teammates.size() - 1)
		_spectate(teammates, next_index)
	elif Input.is_action_just_pressed("attack"):
		_spectate(teammates, (current_index + 1) % teammates.size())
	else:
		spectator_index = current_index


func _spectate(teammates: Array[Player], next_index: int) -> void:
	spectator_index = posmod(next_index, teammates.size())
	var target := teammates[spectator_index]
	spectator_target_id = target.pid
	target.camera.make_current()
	spectator_label.text = "Spectating %s\nClick to switch" % target.player_name()
	spectator_panel.visible = true


func _show_no_teammates(local_player: Player) -> void:
	spectator_target_id = 0
	spectator_index = -1
	if local_player.ragdoll_camera != null:
		local_player.ragdoll_camera.make_current()
	spectator_label.text = "No teammates alive"
	spectator_panel.visible = true


func _reset_spectator() -> void:
	spectator_target_id = 0
	spectator_index = -1
	spectator_panel.visible = false


func _get_player(id: int) -> Player:
	var game := get_parent()
	if game == null or not game.has_method("get_player"):
		return null
	return game.call("get_player", id) as Player


func _players_on_team(team: int) -> Array[Player]:
	var players: Array[Player] = []
	var game := get_parent()
	if game == null or not game.has_method("get_team_players"):
		return players

	var team_players = game.call("get_team_players", team)
	if team_players is Array:
		for player in team_players:
			if player is Player:
				players.append(player)
	return players


func _living_teammates(team: int) -> Array[Player]:
	var teammates: Array[Player] = []
	for player: Player in _players_on_team(team):
		if not player.is_dead:
			teammates.append(player)
	return teammates


func _team_for_player(player: Player) -> int:
	var game := get_parent()
	if game == null or not game.has_method("get_team"):
		return 0
	return int(game.call("get_team", player.pid))


func _find_player_index(players: Array[Player], player_id: int) -> int:
	for index in players.size():
		if players[index].pid == player_id:
			return index
	return -1
