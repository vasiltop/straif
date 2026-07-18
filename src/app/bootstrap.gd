class_name Bootstrap
extends RefCounted

const STEAM_APP_ID := 3850480
const STEAM_WEB_API_IDENTITY := "munost"

const _OFFLINE_PLAYER_ID := 1
const _OFFLINE_DISPLAY_NAME := "Playtester"
const _OFFLINE_TICKET := "offline-playtest-ticket"


class BuildResult:
	extends RefCounted

	var context: AppContext
	var error: String = ""

	func is_ok() -> bool:
		return error.is_empty() and context != null


static func build(
	options: RuntimeOptions, server_bridge: Variant = null, allow_test_adapters := OS.has_feature("editor")
) -> BuildResult:
	var result := BuildResult.new()

	if options == null:
		result.error = "Bootstrap.build requires RuntimeOptions"
		return result

	if not _is_supported_role(options.role):
		result.error = "Bootstrap.build received an unsupported role %d" % options.role
		return result

	var is_server := options.role == RuntimeOptions.Role.DEDICATED_SERVER
	var is_connect := options.role == RuntimeOptions.Role.CONNECT_CLIENT

	if options.offline_playtest and is_server:
		result.error = "Offline playtest is a client-only profile and cannot run a dedicated server"
		return result

	var context := AppContext.new()
	context.options = options

	if options.e2e:
		if not allow_test_adapters:
			result.error = "E2E adapters are only available in test builds"
			return result
		if is_server:
			context.identity = null
			context.server_registry = RecordingServerRegistry.new()
		elif is_connect:
			context.identity = _e2e_identity(options.e2e_instance)
			context.server_registry = null
		else:
			result.error = "E2E is only supported for a dedicated server or a connect client"
			return result
	elif options.offline_playtest:
		context.identity = FakeIdentityProvider.new(_OFFLINE_PLAYER_ID, _OFFLINE_DISPLAY_NAME, _OFFLINE_TICKET)
		context.server_registry = null
	elif is_server:
		if server_bridge == null:
			result.error = "A dedicated server requires a server bridge to publish to the server registry"
			return result
		context.identity = null
		context.server_registry = HttpServerRegistry.new(server_bridge)
	else:
		context.identity = SteamIdentityProvider.new(STEAM_APP_ID, STEAM_WEB_API_IDENTITY)

	var validation := context.validate()
	if not validation.is_empty():
		result.error = validation
		return result

	result.context = context
	return result


static func _e2e_identity(instance: String) -> FakeIdentityProvider:
	var account_id := absi(instance.hash()) + 1
	var display_name := instance.capitalize()
	var ticket := "e2e-%s-ticket" % instance
	return FakeIdentityProvider.new(account_id, display_name, ticket)


static func _is_supported_role(role: int) -> bool:
	return (
		role == RuntimeOptions.Role.MENU_CLIENT
		or role == RuntimeOptions.Role.DEDICATED_SERVER
		or role == RuntimeOptions.Role.CONNECT_CLIENT
	)
