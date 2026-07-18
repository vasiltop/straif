class_name ServerBridge

signal invalid_version

const FILE_CHUNK_SIZE := 1024
const DISCORD_URL := "https://discord.gg/DScF2QqKzF"
const WORLD_RECORD_ALERT_DURATION := 3.0
const MAX_RUN_RECORDING_BYTES := 356148
const WorldRecordAnnouncement = preload("res://src/world_record_announcement.gd")
var client: BetterHTTPClient

var api_url: String
var version: String
var last_aim_overall_leaderboard_available := true

var heartbeat_timer: BetterTimer
var _seen_world_record_ids: Dictionary[String, bool] = { }
var _world_record_messages: Array[String] = []
var _showing_world_records := false

func _settings_file() -> String:
	if OS.has_feature("editor_runtime"):
		return "res://settings-dev.json"
	return "res://settings-prod.json"

func get_leaderboard_base(mode: String) -> String:
	return "/leaderboard/mode/" + mode

func _init() -> void:
	print(_settings_file())
	var file := FileAccess.open(_settings_file(), FileAccess.READ)
	var json: Dictionary = JSON.parse_string(file.get_as_text())

	api_url = json["api_url"]
	version = json["version"]

	client = BetterHTTPClient.new(Global, BetterHTTPURL.parse(api_url))
	heartbeat_timer = BetterTimer.new(Global, 3.0, _on_heartbeat_timer)

func _on_heartbeat_timer() -> void:
	var url := "/game/heartbeat"

	var request := client.http_get(url)
	request.header("auth-ticket", Global.game_manager.auth_ticket_hex)
	request.header("version", version)
	var response := await request.send()

	if not response or response.status() != 200:
		Global.get_tree().change_scene_to_file("res://src/maintenance.tscn")
		return

	var json := await response.json()
	var data: Dictionary = json.data

	Global.game_manager.admin = data.admin as bool
	Global.game_manager.maintenance = data.maintenance as bool
	_handle_world_records(data)

	if not Global.game_manager.maintenance:
		Global.game_manager.maintenance_changed.emit()

	if Global.game_manager.maintenance:
		if Global.game_manager.admin:
			Info.alert("The game is currently under maintenance, allowing play due to admin status.")
		else:
			Global.get_tree().change_scene_to_file("res://src/maintenance.tscn")

func _handle_world_records(data: Dictionary) -> void:
	if not data.has("world_records"):
		return

	var announcements_enabled: bool = Global.settings_manager.value("Game", "world_record_announcements")
	var records: Array = data.world_records as Array
	for record: Dictionary in records:
		var record_id := record.id as String
		if WorldRecordAnnouncement.consume_unseen(record_id, _seen_world_record_ids, announcements_enabled):
			_world_record_messages.append(WorldRecordAnnouncement.format_message(record))
	if not _showing_world_records and not _world_record_messages.is_empty():
		_show_world_record_announcements()

func set_world_record_announcements_enabled(enabled: bool) -> void:
	WorldRecordAnnouncement.clear_if_disabled(_world_record_messages, enabled)

func _show_world_record_announcements() -> void:
	_showing_world_records = true
	while not _world_record_messages.is_empty():
		var announcements_enabled: bool = Global.settings_manager.value("Game", "world_record_announcements")
		WorldRecordAnnouncement.clear_if_disabled(_world_record_messages, announcements_enabled)
		if _world_record_messages.is_empty():
			break
		Info.alert(_world_record_messages.pop_front())
		await Global.get_tree().create_timer(WORLD_RECORD_ALERT_DURATION).timeout
	_showing_world_records = false

func data_or_print_error(response: BetterHTTPResponse, silent := false) -> Variant:
	if response == null:
		if not silent:
			Info.alert("Unable to connect to \nthe game server.")
		return null

	var json := await response.json()
	if json == null:
		return null

	if response.status() != 200:
		if not silent:
			Info.alert("Error code: " + str(response.status()) + ". " + str(json.error as String))
		return null

	return json.data

class MapRunsResponse:
	var runs: Array[Run]
	var total: int

	class Run:
		var time_ms: int
		var username: String
		var created_at: String
		var steam_id: String

		func _init(time_ms: int, username: String, created_at: String, steam_id: String) -> void:
			self.time_ms = time_ms
			self.created_at = created_at
			self.steam_id = steam_id
			self.username = username

	func _init(runs: Array[Run], total: int) -> void:
		self.runs = runs
		self.total = total

class AimScoreEntry:
	var steam_id: String
	var username: String
	var score: int
	var hits: int
	var misses: int
	var accuracy: float
	var avg_reaction_ms: float
	var created_at: String
	var position: int

	func _init(
			steam_id: String,
			username: String,
			score: int,
			hits: int,
			misses: int,
			accuracy: float,
			avg_reaction_ms: float,
			created_at: String,
			position: int,
	) -> void:
		self.steam_id = steam_id
		self.username = username
		self.score = score
		self.hits = hits
		self.misses = misses
		self.accuracy = accuracy
		self.avg_reaction_ms = avg_reaction_ms
		self.created_at = created_at
		self.position = position

class AimScoresResponse:
	var scores: Array[AimScoreEntry]
	var total: int

	func _init(scores: Array[AimScoreEntry], total: int) -> void:
		self.scores = scores
		self.total = total

class AimOverallEntry:
	var steam_id: String
	var username: String
	var total_score: int
	var scenarios_completed: int
	var accuracy: float
	var avg_reaction_ms: float

	func _init(
			steam_id: String,
			username: String,
			total_score: int,
			scenarios_completed: int,
			accuracy: float,
			avg_reaction_ms: float,
	) -> void:
		self.steam_id = steam_id
		self.username = username
		self.total_score = total_score
		self.scenarios_completed = scenarios_completed
		self.accuracy = accuracy
		self.avg_reaction_ms = avg_reaction_ms

class AimScoreSubmissionResult:
	var message: String
	var personal_best: bool
	var score: int
	var position: int

	func _init(message: String, personal_best: bool, score: int, position: int) -> void:
		self.message = message
		self.personal_best = personal_best
		self.score = score
		self.position = position

func _parse_aim_score_entry(entry: Dictionary) -> AimScoreEntry:
	return AimScoreEntry.new(
			entry.steam_id as String,
			entry.username as String,
			entry.score as int,
			entry.hits as int,
			entry.misses as int,
			float(entry.accuracy),
			float(entry.avg_reaction_ms),
			entry.created_at as String,
			entry.position as int,
	)

func _parse_aim_overall_entry(entry: Dictionary) -> AimOverallEntry:
	return AimOverallEntry.new(
			entry.steam_id as String,
			entry.username as String,
			entry.total_score as int,
			entry.scenarios_completed as int,
			float(entry.accuracy),
			float(entry.avg_reaction_ms),
	)

func get_runs(mode: String, map_name: String, page: int) -> MapRunsResponse:
	var url := get_leaderboard_base(mode) + "/maps/%s/runs?page=%d" % [map_name, page - 1]
	var response := await client.http_get(url).send()
	var data := await data_or_print_error(response)

	if data == null:
		return null

	var runs: Array[MapRunsResponse.Run]
	for run: Dictionary in data.runs:
		runs.append(
				MapRunsResponse
				.Run
				.new(run.time_ms as int, run.username as String, run.created_at as String, run.steam_id as String)
		)

	return MapRunsResponse.new(runs, data.total as int)

class PositionalRunResponse:
	var time_ms: int
	var steam_id: String
	var created_at: String
	var username: String
	var position: int

	func _init(time_ms: int, username: String, created_at: String, steam_id: String, position: int) -> void:
		self.time_ms = time_ms
		self.created_at = created_at
		self.steam_id = steam_id
		self.username = username
		self.position = position

func get_my_run_by_map(mode: String, map_name: String) -> PositionalRunResponse:
	var url := get_leaderboard_base(mode) + "/maps/%s/runs/%d" % [map_name, Global.account_id()]
	var response := await client.http_get(url).send()
	var data := await data_or_print_error(response, true)

	if data == null:
		return null

	return PositionalRunResponse.new(
			data.time_ms as int,
			data.username as String,
			data.created_at as String,
			data.steam_id as String,
			data.position as int,
	)

func publish_run(mode: String, recording: PackedByteArray, map_name: String, time_ms: int) -> void:
	if len(recording) > MAX_RUN_RECORDING_BYTES:
		Info.alert("Could not submit run, you went past the run size limit.")
		return

	var request := client.http_post(get_leaderboard_base(mode) + "/maps/%s/runs" % map_name)
	var body := {
		"recording": Marshalls.raw_to_base64(recording),
		"time_ms": time_ms,
		"username": Global.display_name(),
	}
	request.json(body)
	request.header("auth-ticket", Global.game_manager.auth_ticket_hex)
	request.header("version", version)
	var response := await request.send()

	var data := await data_or_print_error(response)

	if data != null:
		var msg := data as String
		Info.alert(msg)

		var mode_info: Dictionary = Global.game_manager.map_name_to_pb_info[map_name].mode_to_map_info[mode]
		var time_s := time_ms / 1000.0
		var is_pb: bool = time_s < mode_info.pb

		if is_pb:
			mode_info.pb = time_s

func is_admin(steam_id: int) -> bool:
	var url := "/admin/player/%d" % steam_id
	var response := await client.http_get(url).header("auth-ticket", Global.game_manager.auth_ticket_hex).send()

	var data := await data_or_print_error(response)
	return data if data else false

func set_maintenance(new_value: bool) -> void:
	var request := client.http_post("/admin/maintenance")
	request.json({ "new_value": new_value })
	request.header("auth-ticket", Global.game_manager.auth_ticket_hex)
	var response := await request.send()

	await data_or_print_error(response)

func set_admin(steam_id: int, new_value: bool) -> void:
	var request := client.http_post("/admin/%d" % steam_id)
	request.json({ "new_value": new_value })
	request.header("auth-ticket", Global.game_manager.auth_ticket_hex)
	var response := await request.send()

	var data := await data_or_print_error(response)
	if data != null:
		Info.alert(data as String)

func delete_run(mode: String, map_name: String, steam_id: int) -> void:
	var url := get_leaderboard_base(mode) + "/maps/%s/runs/%d" % [map_name, steam_id]
	var response := await client.http_delete(url).header("auth-ticket", Global.game_manager.auth_ticket_hex).send()
	var data := await data_or_print_error(response)

	if data != null:
		Info.alert(data as String)

func get_replay(mode: String, map_name: String, steam_id: int) -> String:
	var url := get_leaderboard_base(mode) + "/maps/%s/players/%d/recording" % [map_name, steam_id]
	var response := await client.http_get(url).header("auth-ticket", Global.game_manager.auth_ticket_hex).send()
	var data := await data_or_print_error(response)

	if data == null:
		return ""

	return data

class RunsRequestResponse:
	var runs: Array[Run]

	class Run:
		var time_ms: int
		var map_name: String
		var created_at: String
		var position: int
		var total: int

		func _init(time_ms: int, map_name: String, created_at: String, position: int, total: int) -> void:
			self.time_ms = time_ms
			self.map_name = map_name
			self.created_at = created_at
			self.position = position
			self.total = total

	func _init(runs: Array[Run]) -> void:
		self.runs = runs

func is_banned(steam_id: int) -> bool:
	var response := await client.http_get("/admin/bans/%s" % steam_id).send()
	var data := await data_or_print_error(response)
	return data

func set_ban(steam_id: int, new_value: bool) -> void:
	var request := client.http_post("/admin/bans/%d" % steam_id)
	request.json({ "new_value": new_value })
	request.header("auth-ticket", Global.game_manager.auth_ticket_hex)
	var response := await request.send()

	var data := await data_or_print_error(response)
	if data != null:
		Info.alert(data as String)

func get_my_runs(mode: String) -> RunsRequestResponse:
	var url := get_leaderboard_base(mode) + "/players/%d/runs" % [Global.account_id()]
	var response := await client.http_get(url).send()
	var data := await data_or_print_error(response)
	if data == null:
		return null

	var runs: Array[RunsRequestResponse.Run]
	for run: Dictionary in data:
		runs.append(
				RunsRequestResponse
				.Run
				.new(run.time_ms as int, run.map_name as String, run.created_at as String, run.position as int, run.total as int)
		)

	return RunsRequestResponse.new(runs)

func submit_aim_score(
		scenario: String,
		score: int,
		hits: int,
		misses: int,
		accuracy: float,
		avg_reaction_ms: int,
) -> AimScoreSubmissionResult:
	var request := client.http_post("/leaderboard/aim/scenarios/%s/scores" % scenario)
	var body := {
		"score": score,
		"hits": hits,
		"misses": misses,
		"accuracy": accuracy,
		"avg_reaction_ms": avg_reaction_ms,
		"username": Global.display_name(),
	}
	request.json(body)
	request.header("auth-ticket", Global.game_manager.auth_ticket_hex)
	request.header("version", version)
	var response := await request.send()
	var data := await data_or_print_error(response)
	if data == null:
		return null

	return AimScoreSubmissionResult.new(
			data.message as String,
			data.personal_best as bool,
			data.score as int,
			data.position as int,
	)

func get_aim_scores(scenario: String, page := 1) -> AimScoresResponse:
	var response := await client.http_get("/leaderboard/aim/scenarios/%s/scores?page=%d" % [scenario, page - 1]).send()
	var data := await data_or_print_error(response, true)
	if data == null:
		return null

	var scores: Array[AimScoreEntry]
	for entry: Dictionary in data.scores:
		scores.append(_parse_aim_score_entry(entry))

	return AimScoresResponse.new(scores, data.total as int)

func get_aim_overall_leaderboard() -> Array[AimOverallEntry]:
	var response := await client.http_get("/leaderboard/aim/overall").send()
	var data := await data_or_print_error(response, true)
	if data == null:
		last_aim_overall_leaderboard_available = false
		return []

	last_aim_overall_leaderboard_available = true
	var scores: Array[AimOverallEntry]
	for entry: Dictionary in data.scores:
		scores.append(_parse_aim_overall_entry(entry))
	return scores

func get_overall_leaderboard(mode: String) -> Array:
	var res = await client.http_get(get_leaderboard_base(mode) + "/overall").send()
	var data := await data_or_print_error(res)
	if data == null:
		return []

	return data

class ServerResponse:
	var port: int
	var name: String
	var mode: String
	var map: String
	var player_count: int
	var max_players: int
	var last_ping: String
	var ip: String

func get_servers() -> Array[ServerResponse]:
	var response := await (client.http_get("/browser")).send()
	var data := await data_or_print_error(response)
	if data == null:
		return []

	var res: Array[ServerResponse]

	for s in data:
		var sr := ServerResponse.new()
		sr.port = s.port
		sr.name = s.name
		sr.mode = s.mode
		sr.map = s.map
		sr.player_count = s.player_count
		sr.max_players = s.max_players
		sr.ip = s.ip
		sr.last_ping = s.last_ping
		res.append(sr)

	return res
