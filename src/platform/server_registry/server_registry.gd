class_name ServerRegistry
extends RefCounted


func publish(_snapshot: Dictionary) -> Error:
	push_error("ServerRegistry.publish() must be overridden")
	return ERR_UNCONFIGURED
