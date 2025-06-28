extends Node

#const API_URL := "http://localhost:3000/"
const API_URL := "http://209.38.2.30:3000"
@onready var client := BetterHTTPClient.new(self, BetterHTTPURL.parse(API_URL))

func get_runs(map_name: String, page: int) -> Dictionary:
	var res := await client.http_get("/leaderboard/" + map_name + "?page=" + str(page)).send()
	if res == null: return { "data": [] }
	
	if res.status() != 200:
		return { "data": [] }

	var json: Dictionary = await res.json()
	return json

func publish_run(recording: PackedByteArray, map_name: String, time_ms: int) -> void:
	await client.http_post("/leaderboard").json({
			"recording": Marshalls.raw_to_base64(recording),
			"map_name": map_name,
			"time_ms": time_ms,
			"username": Steam.getPersonaName(),
		}).header("auth-ticket", str(Lobby.auth_ticket_hex)).send()

func check_admin() -> bool:
	var res := await client.http_get("/leaderboard/admin").header("auth-ticket", str(Lobby.auth_ticket_hex)).send()
	if res == null: return false
	
	if res.status() == 200:
		return true
	
	return false

func get_replay(map_name: String, steam_id: int) -> String:
	var res := await client.http_get("/leaderboard/" + map_name + "/" + str(steam_id) + "/recording").header("auth-ticket", str(Lobby.auth_ticket_hex)).send()
	if res == null: return ""
	
	if res.status() != 200:
		return ""
	
	var json: Dictionary = await res.json()
	return json.data.recording

func get_my_runs() -> Array:
	var res := await client.http_get("/leaderboard/" + str(Steam.getSteamID()) + "/runs").send()
	if res == null: return []

	if res.status() != 200:
		return []

	var json: Dictionary = await res.json()
	return json.data
