class_name RuntimeOptions
extends RefCounted

enum Role {
	MENU_CLIENT,
	DEDICATED_SERVER,
	CONNECT_CLIENT,
}

const SUPPORTED_SERVER_MODES := ["deathmatch", "elimination"]

var role: Role = Role.MENU_CLIENT
var e2e: bool = false
var offline_playtest: bool = false
var server_name: String = ""
var port: int = 0
var max_players: int = 0
var mode: String = ""
var connect_host: String = ""
var connect_port: int = 0
var e2e_instance: String = ""
var e2e_control_port: int = 0

class ParseResult:
	extends RefCounted

	var options: RuntimeOptions
	var error: String = ""

	func is_ok() -> bool:
		return error.is_empty()

static func parse(args: PackedStringArray, allow_e2e: bool) -> ParseResult:
	var result := ParseResult.new()
	var options := new()
	result.options = options

	var count := args.size()
	var index := 0

	if index < count and not args[index].begins_with("--"):
		var command := args[index]
		match command:
			"server":
				var error := _parse_server(args, index, options)
				if not error.is_empty():
					result.error = error
					return result
				index += 5
			"connect":
				var error := _parse_connect(args, index, options)
				if not error.is_empty():
					result.error = error
					return result
				index += 3
			_:
				result.error = "Unknown command '%s'. Expected 'server', 'connect', or a flag." % command
				return result

	while index < count:
		var arg := args[index]
		match arg:
			"--offline-playtest":
				options.offline_playtest = true
				index += 1
			"--e2e":
				options.e2e = true
				index += 1
			"--e2e-instance":
				var error := _parse_e2e_instance(args, index, options)
				if not error.is_empty():
					result.error = error
					return result
				index += 2
			"--e2e-control-port":
				var error := _parse_e2e_control_port(args, index, options)
				if not error.is_empty():
					result.error = error
					return result
				index += 2
			_:
				result.error = "Unknown argument '%s'" % arg
				return result

	var validation := _validate(options, allow_e2e)
	if not validation.is_empty():
		result.error = validation
		return result

	return result

static func _parse_server(args: PackedStringArray, start_index: int, options: RuntimeOptions) -> String:
	if start_index + 4 >= args.size():
		return "server requires exactly 4 arguments: <name> <port> <max_players> <mode>"

	var name := args[start_index + 1]
	var port_str := args[start_index + 2]
	var max_players_str := args[start_index + 3]
	var mode := args[start_index + 4]

	if name.is_empty():
		return "server name must not be empty"
	if name.begins_with("--"):
		return "server name must not look like a flag, got '%s'" % name
	if mode.is_empty():
		return "server mode must not be empty"
	if mode.begins_with("--"):
		return "server mode must not look like a flag, got '%s'" % mode
	if not SUPPORTED_SERVER_MODES.has(mode):
		return "server mode must be one of %s, got '%s'" % [", ".join(PackedStringArray(SUPPORTED_SERVER_MODES)), mode]
	if not port_str.is_valid_int():
		return "server port must be an integer, got '%s'" % port_str
	var port := int(port_str)
	if port < 1 or port > 65535:
		return "server port must be between 1 and 65535, got %d" % port
	if not max_players_str.is_valid_int():
		return "server max players must be an integer, got '%s'" % max_players_str
	var max_players := int(max_players_str)
	if max_players <= 0:
		return "server max players must be greater than 0, got %d" % max_players

	options.role = Role.DEDICATED_SERVER
	options.server_name = name
	options.port = port
	options.max_players = max_players
	options.mode = mode
	return ""

static func _parse_connect(args: PackedStringArray, start_index: int, options: RuntimeOptions) -> String:
	if start_index + 2 >= args.size():
		return "connect requires exactly 2 arguments: <host> <port>"

	var host := args[start_index + 1]
	var port_str := args[start_index + 2]

	if host.is_empty():
		return "connect host must not be empty"
	if host.begins_with("--"):
		return "connect host must not look like a flag, got '%s'" % host
	if not port_str.is_valid_int():
		return "connect port must be an integer, got '%s'" % port_str
	var port := int(port_str)
	if port < 1 or port > 65535:
		return "connect port must be between 1 and 65535, got %d" % port

	options.role = Role.CONNECT_CLIENT
	options.connect_host = host
	options.connect_port = port
	return ""

static func _parse_e2e_instance(args: PackedStringArray, flag_index: int, options: RuntimeOptions) -> String:
	var value: Variant = _flag_value(args, flag_index)
	if value == null:
		return "--e2e-instance requires a value"
	var instance := value as String
	if instance.is_empty():
		return "--e2e-instance must not be empty"
	options.e2e_instance = instance
	return ""

static func _parse_e2e_control_port(args: PackedStringArray, flag_index: int, options: RuntimeOptions) -> String:
	var value: Variant = _flag_value(args, flag_index)
	if value == null:
		return "--e2e-control-port requires a value"
	var port_str := value as String
	if not port_str.is_valid_int():
		return "--e2e-control-port must be an integer, got '%s'" % port_str
	var control_port := int(port_str)
	if control_port < 1 or control_port > 65535:
		return "--e2e-control-port must be between 1 and 65535, got %d" % control_port
	options.e2e_control_port = control_port
	return ""

static func _flag_value(args: PackedStringArray, flag_index: int) -> Variant:
	var value_index := flag_index + 1
	if value_index >= args.size():
		return null
	var value := args[value_index]
	if value.begins_with("--"):
		return null
	return value

static func _validate(options: RuntimeOptions, allow_e2e: bool) -> String:
	var has_instance := not options.e2e_instance.is_empty()
	var has_control_port := options.e2e_control_port != 0

	if not options.e2e:
		if has_instance:
			return "--e2e-instance requires --e2e"
		if has_control_port:
			return "--e2e-control-port requires --e2e"
		return ""

	if not allow_e2e:
		return "--e2e is only allowed in end-to-end test builds"

	if options.role != Role.DEDICATED_SERVER and options.role != Role.CONNECT_CLIENT:
		return "--e2e is only supported for a dedicated server or a connect client"

	if not has_instance:
		return "--e2e requires --e2e-instance"
	if not has_control_port:
		return "--e2e requires --e2e-control-port"

	return ""
