class_name FakeIdentityProvider
extends IdentityProvider

var _player_id: int
var _display_name: String
var _ticket: String


static func is_valid_config(player_id: int, display_name: String, ticket: String) -> bool:
	return player_id > 0 and not display_name.is_empty() and not ticket.is_empty()


func _init(player_id: int, display_name: String, ticket: String) -> void:
	assert(
		is_valid_config(player_id, display_name, ticket),
		"FakeIdentityProvider requires a positive id, a nonempty name, and a nonempty ticket"
	)
	_player_id = player_id
	_display_name = display_name
	_ticket = ticket


func initialize() -> Error:
	return OK


func player_id() -> int:
	return _player_id


func display_name() -> String:
	return _display_name


func request_auth_ticket() -> void:
	auth_ticket_ready.emit(_ticket)
