class_name IdentityProvider
extends RefCounted

signal auth_ticket_ready(ticket: String)

signal auth_ticket_failed(message: String)


func initialize() -> Error:
	push_error("IdentityProvider.initialize() must be overridden")
	return ERR_UNCONFIGURED


func player_id() -> int:
	push_error("IdentityProvider.player_id() must be overridden")
	return 0


func display_name() -> String:
	push_error("IdentityProvider.display_name() must be overridden")
	return ""


func request_auth_ticket() -> void:
	push_error("IdentityProvider.request_auth_ticket() must be overridden")
