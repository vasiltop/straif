class_name ServerBridge

signal invalid_version

const FILE_CHUNK_SIZE := 1024
const DISCORD_URL := "https://discord.gg/TEqDBNPQSs"

var client: BetterHTTPClient 
#var api_url := "http://localhost:3000" if OS.has_feature("editor") else "https://straifapi.pumped.software"
#var api_url := "https://straifapi.pumped.software"
var api_url := "https://straifapi-staging.pumped.software"
var version := "0.1.7"
#var version := "dev" if OS.has_feature("editor") else "0.1.7"
var heartbeat_timer: BetterTimer

func get_leaderboard_base(mode: String) -> String:
	return "/leaderboard/mode/" + mode

func _init() -> void:
	client = BetterHTTPClient.new(Global, BetterHTTPURL.parse(api_url))
	# We start this timer after we receive our auth ticket in the game_manager.gd
	heartbeat_timer = BetterTimer.new(Global, 3.0, _on_heartbeat_timer)

func _on_heartbeat_timer() -> void:
	var url := "/game/heartbeat"
	var response := await client.http_get(url).header(
		"auth-ticket", Global.game_manager.auth_ticket_hex
		).header(
			"version", version
		).send()

	if response.status() != 200:
		Global.get_tree().change_scene_to_file("res://src/maintenance.tscn")
		return
	
	var json := await response.json()
	var data: Dictionary = json.data

	Global.game_manager.admin = data.admin as bool
	Global.game_manager.maintenance = data.maintenance as bool
	
	if not Global.game_manager.maintenance:
		Global.game_manager.maintenance_changed.emit()
	
	if Global.game_manager.maintenance:
		if Global.game_manager.admin:
			Info.alert("The game is currently under maintenance, allowing play due to admin status.")
		else:
			Global.get_tree().change_scene_to_file("res://src/maintenance.tscn")

func data_or_print_error(response: BetterHTTPResponse, silent := false) -> Variant:
	# This works due to a convention of the web server to return either:
	'''
	{
		error: String
	}
	or
	{
		data: Variant
	}
	'''
	# Also, all success responses will have the code 200, since we don't care what the code is.
	
	if response == null:
		if not silent:
			Info.alert("Unable to connect to \nthe game server.")
		return null

	var json := await response.json()
	if json == null: return null
	
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
		
		func _init(
			time_ms: int,
			username: String,
			created_at: String,
			steam_id: String
			) -> void:
			self.time_ms = time_ms
			self.created_at = created_at
			self.steam_id = steam_id
			self.username = username
			
	func _init(runs: Array[Run], total: int) -> void:
		self.runs = runs
		self.total = total

func get_runs(mode: String, map_name: String, page: int) -> MapRunsResponse:
	var url := get_leaderboard_base(mode) + "/maps/%s/runs?page=%d" % [map_name, page - 1]
	var response := await client.http_get(url).send()
	var data: Dictionary = await data_or_print_error(response)
	
	var runs: Array[MapRunsResponse.Run]
	for run: Dictionary in data.runs:
		runs.append(MapRunsResponse.Run.new(
			run.time_ms as int,
			run.username as String,
			run.created_at as String,
			run.steam_id as String
		))
	
	return MapRunsResponse.new(runs, data.total as int)

class PositionalRunResponse:
	var time_ms: int
	var steam_id: String
	var created_at: String
	var username: String
	var position: int

	func _init(
		time_ms: int,
		username: String,
		created_at: String,
		steam_id: String,
		position: int
		) -> void:
		self.time_ms = time_ms
		self.created_at = created_at
		self.steam_id = steam_id
		self.username = username
		self.position = position
		
func get_my_run_by_map(mode: String, map_name: String) -> PositionalRunResponse:
	var url := get_leaderboard_base(mode) + "/maps/%s/runs/%d" % [map_name, Steam.getSteamID()]
	var response := await client.http_get(url).send()
	var data := await data_or_print_error(response, true)

	if data == null: return null
	
	return PositionalRunResponse.new(data.time_ms as int, data.username as String, data.created_at as String, data.steam_id as String, data.position as int)

func publish_run(mode: String, recording: PackedByteArray, map_name: String, time_ms: int) -> void:
	if len(recording) > 356148:
		# 356148 = 370s
		Info.alert("Could not submit run, you went past the run size limit.")
		return
	
	var response := await client.http_post(get_leaderboard_base(mode) + "/maps/%s/runs" % map_name).json({
			"recording": Marshalls.raw_to_base64(recording),
			"time_ms": time_ms,
			"username": Steam.getPersonaName(),
		}).header(
			"auth-ticket", Global.game_manager.auth_ticket_hex
			).header(
				"version", version
				).send()

	var data := await data_or_print_error(response)
	
	if data != null:
		Info.alert(data as String)

func is_admin(steam_id: int) -> bool:
	var url := "/admin/player/%d" % steam_id 
	var response := await client.http_get(url).header(
			"auth-ticket", Global.game_manager.auth_ticket_hex
			).send()
			
	var data := await data_or_print_error(response)
	return data if data else false

func set_maintenance(new_value: bool) -> void:
	var response := await client.http_post("/admin/maintenance").json({
		"new_value": new_value
		}).header(
			"auth-ticket", Global.game_manager.auth_ticket_hex
			).send()
	
	await data_or_print_error(response)

func set_admin(steam_id: int, new_value: bool) -> void:
	var response := await client.http_post("/admin/%d" % steam_id).json({
		"new_value": new_value
		}).header(
			"auth-ticket", Global.game_manager.auth_ticket_hex
			).send()

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
	
	if data == null: return ""
	
	return data

class RunsRequestResponse:
	var runs: Array[Run]
	
	class Run:
		var time_ms: int
		var map_name: String
		var created_at: String
		var position: int
		var total: int
		
		func _init(
			time_ms: int,
			map_name: String,
			created_at: String,
			position: int,
			total: int
		) -> void:
			self.time_ms = time_ms
			self.map_name = map_name
			self.created_at = created_at
			self.position = position
			self.total = total
			
	func _init(runs: Array[Run]) -> void:
		self.runs = runs

func get_my_runs(mode: String) -> RunsRequestResponse:
	var url := get_leaderboard_base(mode) + "/players/%d/runs" % [Steam.getSteamID()]
	var response := await client.http_get(url).send()
	var data := await data_or_print_error(response)
	if data == null: return null

	var runs: Array[RunsRequestResponse.Run]
	for run: Dictionary in data:
		runs.append(RunsRequestResponse.Run.new(run.time_ms as int, run.map_name as String, run.created_at as String, run.position as int, run.total as int))
	return RunsRequestResponse.new(runs)
