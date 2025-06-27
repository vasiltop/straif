extends Node

const API_URL := "http://localhost:3000/"
@onready var client := BetterHTTPClient.new(self, BetterHTTPURL.parse(API_URL))

func get_runs(map_name: String, page: int) -> Dictionary:
	var res := await client.http_get("/leaderboard/" + map_name + "?page=" + str(page)).send()
	var json: Dictionary = await res.json()

	return json

func publish_run(recording: PackedByteArray, map_name: String, time_ms: int) -> void:
	await client.http_post("/leaderboard").json({
			"steam_id": Steam.getSteamID(),
			"recording": Marshalls.raw_to_base64(recording),
			"map_name": map_name,
			"time_ms": time_ms 
		}).send()

	#var json: Dictionary = await res.json()
