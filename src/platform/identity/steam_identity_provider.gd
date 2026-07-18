class_name SteamIdentityProvider
extends IdentityProvider

var _app_id: int
var _web_api_identity: String
var _initialized := false
var _signal_connected := false

func _init(app_id: int, web_api_identity: String) -> void:
	_app_id = app_id
	_web_api_identity = web_api_identity

func initialize() -> Error:
	if _initialized:
		return OK
	var result := Steam.steamInitEx(_app_id, true)
	if result.status != Steam.SteamAPIInitResult.STEAM_API_INIT_RESULT_OK:
		return FAILED
	_initialized = true
	if not _signal_connected:
		Steam.get_ticket_for_web_api.connect(_on_get_ticket_for_web_api)
		_signal_connected = true
	return OK

func player_id() -> int:
	return Steam.getSteamID()

func display_name() -> String:
	return Steam.getPersonaName()

func request_auth_ticket() -> void:
	Steam.getAuthTicketForWebApi(_web_api_identity)

func _on_get_ticket_for_web_api(_auth_ticket: int, result: int, _ticket_size: int, ticket_buffer: Array) -> void:
	if result != Steam.RESULT_OK:
		auth_ticket_failed.emit("Steam returned result %d while producing a web API ticket" % result)
		return
	var hex := PackedByteArray(ticket_buffer).hex_encode()
	if hex.is_empty():
		auth_ticket_failed.emit("Steam produced an empty web API ticket")
		return
	auth_ticket_ready.emit(hex)
