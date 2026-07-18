extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var global_node := root.get_node_or_null("Global")
	_check(global_node != null, "Global autoload should exist during the smoke test")

	if global_node != null:
		_check(
				global_node.is_offline_playtest_mode(PackedStringArray(["--offline-playtest"])),
				"Offline helper should enable on the exact flag",
		)
		_check(
				not global_node.is_offline_playtest_mode(PackedStringArray(["--offline-playtestx"])),
				"Offline helper should ignore partial flag matches",
		)

		var context: Variant = await _await_context(global_node)
		_check(global_node.offline_playtest, "Global should report offline playtest mode when launched with the flag")
		_check(context != null, "Global should build an AppContext during startup")

		if context != null and context.identity != null:
			var got := { "ticket": "" }
			context.identity.auth_ticket_ready.connect(func(ticket: String) -> void: got["ticket"] = ticket)
			context.identity.request_auth_ticket()
			_check(got["ticket"] != "", "Offline identity should deliver an auth ticket without contacting Steam")

			_check(
					global_node.account_id() == 1,
					"Global should surface the offline account id 1 from its identity provider",
			)
			_check(
					global_node.display_name() == "Playtester",
					"Global should surface the offline display name Playtester from its identity provider",
			)
			_check(
					not global_node.steam_available(),
					"Global should report Steam as unavailable during offline playtest",
			)

	quit(1 if failed else 0)

func _await_context(global_node: Node) -> Variant:
	for _i in range(600):
		if global_node.context != null:
			return global_node.context
		await process_frame
	return global_node.context

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
