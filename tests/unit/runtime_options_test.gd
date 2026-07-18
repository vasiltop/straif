extends SceneTree

const RuntimeOptions = preload("res://src/app/runtime_options.gd")
const TestCase = preload("res://tests/support/test_case.gd")


func _init() -> void:
	var t := TestCase.new()

	_test_empty_args_default_menu(t)
	_test_valid_server(t)
	_test_server_missing_or_invalid_positionals(t)
	_test_unknown_command_flag_and_extra(t)
	_test_offline_playtest_flag(t)
	_test_server_rejects_flag_like_positionals(t)
	_test_valid_connect_with_e2e(t)
	_test_invalid_connect(t)
	_test_e2e_value_flags_reject_flag_values(t)
	_test_e2e_role_gating(t)

	quit(t.finish())


func _test_empty_args_default_menu(t: TestCase) -> void:
	var result := RuntimeOptions.parse(PackedStringArray([]), false)
	t.check(result.is_ok(), "Empty args should parse without error, got: %s" % result.error)
	if result.is_ok():
		t.check_equal(result.options.role, RuntimeOptions.Role.MENU_CLIENT, "Empty args should default to MENU_CLIENT")
		t.check(not result.options.e2e, "Empty args should not enable e2e")
		t.check(not result.options.offline_playtest, "Empty args should not enable offline playtest")


func _test_valid_server(t: TestCase) -> void:
	var args := PackedStringArray(["server", "DM-1", "3005", "5", "deathmatch"])
	var result := RuntimeOptions.parse(args, false)
	t.check(result.is_ok(), "Valid server args should parse without error, got: %s" % result.error)
	if result.is_ok():
		t.check_equal(
			result.options.role, RuntimeOptions.Role.DEDICATED_SERVER, "Server args should set role to DEDICATED_SERVER"
		)
		t.check_equal(result.options.server_name, "DM-1", "Server name should be captured")
		t.check_equal(result.options.port, 3005, "Server port should be parsed as an integer")
		t.check_equal(result.options.max_players, 5, "Server max players should be parsed as an integer")
		t.check_equal(result.options.mode, "deathmatch", "Server mode should be captured")


func _test_server_missing_or_invalid_positionals(t: TestCase) -> void:
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["server", "DM-1", "3005"]), false).is_ok(),
		"Server with missing positionals should error"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["server"]), false).is_ok(),
		"Server with no positionals should error"
	)

	t.check(
		not RuntimeOptions.parse(PackedStringArray(["server", "", "3005", "5", "deathmatch"]), false).is_ok(),
		"Server with an empty name should error"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["server", "DM-1", "3005", "5", ""]), false).is_ok(),
		"Server with an empty mode should error"
	)

	t.check(
		not RuntimeOptions.parse(PackedStringArray(["server", "DM-1", "abc", "5", "deathmatch"]), false).is_ok(),
		"Server with a non-numeric port should error"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["server", "DM-1", "0", "5", "deathmatch"]), false).is_ok(),
		"Server port 0 should error (out of 1..65535 range)"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["server", "DM-1", "70000", "5", "deathmatch"]), false).is_ok(),
		"Server port above 65535 should error"
	)

	t.check(
		not RuntimeOptions.parse(PackedStringArray(["server", "DM-1", "3005", "abc", "deathmatch"]), false).is_ok(),
		"Server with a non-numeric max players should error"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["server", "DM-1", "3005", "0", "deathmatch"]), false).is_ok(),
		"Server with 0 max players should error"
	)

	var unsupported_mode := RuntimeOptions.parse(
		PackedStringArray(["server", "DM-1", "3005", "5", "deathmtach"]), false
	)
	t.check(not unsupported_mode.is_ok(), "Server with an unsupported mode should error")
	t.check(unsupported_mode.error.contains("deathmtach"), "The error should name the unsupported server mode value")


func _test_unknown_command_flag_and_extra(t: TestCase) -> void:
	t.check(not RuntimeOptions.parse(PackedStringArray(["launch"]), false).is_ok(), "Unknown command should error")
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["--not-a-real-flag"]), false).is_ok(), "Unknown flag should error"
	)
	t.check(
		not (
			RuntimeOptions
			. parse(PackedStringArray(["server", "DM-1", "3005", "5", "deathmatch", "extra"]), false)
			. is_ok()
		),
		"Extra positional after valid server args should error"
	)


func _test_offline_playtest_flag(t: TestCase) -> void:
	var result := RuntimeOptions.parse(PackedStringArray(["--offline-playtest"]), false)
	t.check(result.is_ok(), "Exact --offline-playtest flag should parse without error, got: %s" % result.error)
	if result.is_ok():
		t.check(result.options.offline_playtest, "--offline-playtest should set offline_playtest to true")
		t.check_equal(
			result.options.role,
			RuntimeOptions.Role.MENU_CLIENT,
			"--offline-playtest alone should still default to MENU_CLIENT"
		)

	t.check(
		not RuntimeOptions.parse(PackedStringArray(["--offline-playtestx"]), false).is_ok(),
		"A partial match of --offline-playtest should not be accepted as the flag"
	)


func _test_valid_connect_with_e2e(t: TestCase) -> void:
	var args := PackedStringArray(
		["connect", "127.0.0.1", "5000", "--e2e", "--e2e-instance", "alice", "--e2e-control-port", "6001"]
	)
	var result := RuntimeOptions.parse(args, true)
	t.check(result.is_ok(), "Valid connect + e2e args should parse without error, got: %s" % result.error)
	if result.is_ok():
		t.check_equal(
			result.options.role, RuntimeOptions.Role.CONNECT_CLIENT, "connect should set role to CONNECT_CLIENT"
		)
		t.check_equal(result.options.connect_host, "127.0.0.1", "connect host should be consumed")
		t.check_equal(result.options.connect_port, 5000, "connect port should be parsed as an integer")
		t.check(result.options.e2e, "--e2e should set e2e to true")
		t.check_equal(result.options.e2e_instance, "alice", "--e2e-instance should consume its value")
		t.check_equal(result.options.e2e_control_port, 6001, "--e2e-control-port should parse its value as an integer")


func _test_invalid_connect(t: TestCase) -> void:
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["connect", "127.0.0.1"]), false).is_ok(),
		"connect with a missing port should error"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["connect", "", "5000"]), false).is_ok(),
		"connect with an empty host should error"
	)

	var flag_host := RuntimeOptions.parse(PackedStringArray(["connect", "--sneaky", "5000"]), false)
	t.check(not flag_host.is_ok(), "connect host that looks like a flag should error")
	t.check(flag_host.error.contains("--sneaky"), "The error should name the offending connect host value")

	t.check(
		not RuntimeOptions.parse(PackedStringArray(["connect", "127.0.0.1", "abc"]), false).is_ok(),
		"connect with a non-integer port should error"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["connect", "127.0.0.1", "0"]), false).is_ok(),
		"connect port 0 should error (out of 1..65535 range)"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["connect", "127.0.0.1", "70000"]), false).is_ok(),
		"connect port above 65535 should error"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["connect", "127.0.0.1", "5000", "extra"]), false).is_ok(),
		"Extra positional after valid connect args should error"
	)


func _test_e2e_value_flags_reject_flag_values(t: TestCase) -> void:
	t.check(
		not (
			RuntimeOptions
			. parse(
				PackedStringArray(
					["connect", "127.0.0.1", "5000", "--e2e", "--e2e-instance", "--e2e-control-port", "6001"]
				),
				true
			)
			. is_ok()
		),
		"--e2e-instance must not consume a following flag as its value"
	)
	t.check(
		not (
			RuntimeOptions
			. parse(
				PackedStringArray(
					["connect", "127.0.0.1", "5000", "--e2e", "--e2e-instance", "alice", "--e2e-control-port", "--e2e"]
				),
				true
			)
			. is_ok()
		),
		"--e2e-control-port must not consume a following flag as its value"
	)
	t.check(
		not (
			RuntimeOptions
			. parse(PackedStringArray(["connect", "127.0.0.1", "5000", "--e2e", "--e2e-instance"]), true)
			. is_ok()
		),
		"--e2e-instance without a value should error"
	)
	t.check(
		not (
			RuntimeOptions
			. parse(
				PackedStringArray(
					["connect", "127.0.0.1", "5000", "--e2e", "--e2e-instance", "alice", "--e2e-control-port", "abc"]
				),
				true
			)
			. is_ok()
		),
		"--e2e-control-port with a non-integer value should error"
	)
	t.check(
		not (
			RuntimeOptions
			. parse(
				PackedStringArray(
					["connect", "127.0.0.1", "5000", "--e2e", "--e2e-instance", "alice", "--e2e-control-port", "70000"]
				),
				true
			)
			. is_ok()
		),
		"--e2e-control-port out of the 1..65535 range should error"
	)


func _test_e2e_role_gating(t: TestCase) -> void:
	var server_e2e := RuntimeOptions.parse(
		PackedStringArray(
			[
				"server",
				"DM-1",
				"3005",
				"8",
				"deathmatch",
				"--e2e",
				"--e2e-instance",
				"srv",
				"--e2e-control-port",
				"6002"
			]
		),
		true
	)
	t.check(server_e2e.is_ok(), "server + e2e + instance + control port should parse, got: %s" % server_e2e.error)
	if server_e2e.is_ok():
		t.check_equal(
			server_e2e.options.role, RuntimeOptions.Role.DEDICATED_SERVER, "server e2e keeps the dedicated server role"
		)
		t.check(server_e2e.options.e2e, "server e2e should set e2e to true")

	t.check(
		not (
			RuntimeOptions
			. parse(PackedStringArray(["--e2e", "--e2e-instance", "alice", "--e2e-control-port", "6001"]), true)
			. is_ok()
		),
		"e2e for a menu client should be rejected"
	)
	t.check(
		not (
			RuntimeOptions
			. parse(
				PackedStringArray(
					["connect", "127.0.0.1", "5000", "--e2e", "--e2e-instance", "alice", "--e2e-control-port", "6001"]
				),
				false
			)
			. is_ok()
		),
		"e2e should be rejected in a production build"
	)
	t.check(
		not RuntimeOptions.parse(PackedStringArray(["connect", "127.0.0.1", "5000", "--e2e"]), true).is_ok(),
		"e2e without an instance and control port should be rejected"
	)
	t.check(
		not (
			RuntimeOptions
			. parse(PackedStringArray(["connect", "127.0.0.1", "5000", "--e2e-instance", "alice"]), true)
			. is_ok()
		),
		"An e2e-only flag without --e2e should be rejected"
	)


func _test_server_rejects_flag_like_positionals(t: TestCase) -> void:
	var server_name_like_flag := RuntimeOptions.parse(
		PackedStringArray(["server", "--sneaky", "3005", "5", "deathmatch"]), false
	)
	t.check(not server_name_like_flag.is_ok(), "A server name that looks like a flag should error")
	t.check(server_name_like_flag.error.contains("--sneaky"), "The error should name the offending server name value")

	var server_mode_like_flag := RuntimeOptions.parse(
		PackedStringArray(["server", "DM-1", "3005", "5", "--sneaky"]), false
	)
	t.check(not server_mode_like_flag.is_ok(), "A server mode that looks like a flag should error")
	t.check(server_mode_like_flag.error.contains("--sneaky"), "The error should name the offending server mode value")
