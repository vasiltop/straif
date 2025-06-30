extends Node

signal invalid_version

const API_URL := "http://localhost:3000"
#const API_URL := "http://209.38.2.30:3000"
const GAME_VERSION := 1
const FILE_CHUNK_SIZE := 1024
const DOWNLOAD_URL := "https://munost.itch.io/straif-2/download/A7Cj5QebP4wvf18G6oMGKwwbRFPT9pPofQ3i0C_X"

@onready var client := BetterHTTPClient.new(self, BetterHTTPURL.parse(API_URL))

var game_hash: String

func _show_connection_error() -> void:
	Info.alert("Unable to connect to \nthe game server.")

func _ready() -> void:
	if not OS.is_debug_build():
		_generate_game_hash()

	var res := await client.http_get("/leaderboard/version").send()
	if res == null: 
		_show_connection_error()
		return
	
	if res.status() != 200:
		return
	
	var json: Dictionary = await res.json()
	var version := int(json.data as String)
	
	if version != GAME_VERSION:
		invalid_version.emit()
		OS.shell_open(DOWNLOAD_URL)
	
	#_gen_hash("res://bin/straif2.pck")

func _generate_game_hash() -> void:
	var path := OS.get_executable_path()
	var pck := path.get_basename() + ".pck"
	print("Pck file hash: ")
	print(_gen_hash(pck))

func _gen_hash(path: String) -> String:
	if not FileAccess.file_exists(path):
		Info.alert("Could not located .pck file")
		return ""
	
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var file := FileAccess.open(path, FileAccess.READ)

	while file.get_position() < file.get_length():
		var remaining := file.get_length() - file.get_position()
		ctx.update(file.get_buffer(min(remaining, FILE_CHUNK_SIZE) as int))
	
	var res := ctx.finish()
	return res.hex_encode()

func get_runs(map_name: String, page: int) -> Array:
	var res := await client.http_get("/leaderboard/" + map_name + "?page=" + str(page)).send()
	if res == null: 
		_show_connection_error()
		return []
	
	var json: Dictionary = await res.json()
	if res.status() != 200:
		Info.alert(json.error as String)
		return []

	return json.data as Array

func publish_run(recording: PackedByteArray, map_name: String, time_ms: int) -> void:
	var res := await client.http_post("/leaderboard").json({
			"recording": Marshalls.raw_to_base64(recording),
			"map_name": map_name,
			"time_ms": time_ms,
			"username": Steam.getPersonaName(),
		}).header("auth-ticket", str(Lobby.auth_ticket_hex)).send()

	if res == null:
		_show_connection_error()

func check_admin() -> bool:
	var res := await client.http_get("/leaderboard/admin").header("auth-ticket", str(Lobby.auth_ticket_hex)).send()
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
