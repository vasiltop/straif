class_name AppContext
extends RefCounted

var options: RuntimeOptions
var identity: IdentityProvider
var server_registry: ServerRegistry

func validate() -> String:
	if options == null:
		return "AppContext requires RuntimeOptions"

	match options.role:
		RuntimeOptions.Role.DEDICATED_SERVER:
			if server_registry == null:
				return "A dedicated server requires a ServerRegistry"
		RuntimeOptions.Role.MENU_CLIENT, RuntimeOptions.Role.CONNECT_CLIENT:
			if identity == null:
				return "A client requires an IdentityProvider"
		_:
			return "Unsupported role %d" % options.role

	return ""
