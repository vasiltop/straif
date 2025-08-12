extends Node

signal invalid_version

const FILE_CHUNK_SIZE := 1024
const DISCORD_URL := "https://discord.gg/TEqDBNPQSs"

var client: BetterHTTPClient 
var api_url := "http://localhost:3000" if OS.has_feature("editor") else "https://straifapi.pumped.software/"
var version := "dev" if OS.has_feature("editor") else "0.03"

func _show_connection_error() -> void:
	Info.alert("Unable to connect to \nthe game server.")

func _ready() -> void:
	client = BetterHTTPClient.new(self, BetterHTTPURL.parse(api_url))
	
	var res := await client.http_get("/version").header("version", version).send()
	if res == null: 
		_show_connection_error()
		return
		
	if res.status() != 200:
		invalid_version.emit()
		return

func get_runs(map_name: String, page: int) -> Dictionary:
	var res := await client.http_get("/leaderboard/" + map_name + "?page=" + str(page - 1)).send()

	if res == null: 
		_show_connection_error()
		return {}
	
	var json: Dictionary = await res.json()
	if res.status() != 200:
		Info.alert(json.error as String)
		return {}

	return json as Dictionary

func get_my_run(map_name: String) -> Dictionary:
	var res := await client.http_get("/leaderboard/" + map_name + "/" + str(Steam.getSteamID())).send()
	if res == null:
		_show_connection_error()
		return {}
		
	var json: Dictionary = await res.json()
	if res.status() != 200:
		return {}

	return json.data as Dictionary

func publish_run(recording: PackedByteArray, map_name: String, time_ms: int) -> void:
	if len(recording) > 356148:
		# 356148 = 370s
		Info.alert("Could not submit run, you went past the run size limit.")
		return
	
	var res := await client.http_post("/leaderboard").json({
			"recording": Marshalls.raw_to_base64(recording),
			"map_name": map_name,
			"time_ms": time_ms,
			"username": Steam.getPersonaName(),
		}).header(
			"auth-ticket", str(Lobby.auth_ticket_hex)
			).header(
				"version", version
				).send()

	if res == null:
		_show_connection_error()

func check_admin() -> bool:
	var res := await client.http_get("/admin").header("auth-ticket", str(Lobby.auth_ticket_hex)).send()
	if res == null: 
		_show_connection_error()
		return false

	if res.status() == 200:
		return true
	
	return false

func get_replay(map_name: String, steam_id: int) -> String:
	var res := await client.http_get("/leaderboard/" + map_name + "/" + str(steam_id) + "/recording").header("auth-ticket", str(Lobby.auth_ticket_hex)).send()
	if res == null: 
		_show_connection_error()
		return ""
	
	if res.status() != 200:
		return ""
	
	var json: Dictionary = await res.json()
	return json.data.recording

func get_my_runs() -> Array:
	var res := await client.http_get("/leaderboard/" + str(Steam.getSteamID()) + "/runs").send()
	if res == null: 
		_show_connection_error()
		return []

	if res.status() != 200:
		return []

	var json: Dictionary = await res.json()
	return json.data
