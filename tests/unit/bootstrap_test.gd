extends SceneTree

const RuntimeOptions = preload("res://src/app/runtime_options.gd")
const Bootstrap = preload("res://src/app/bootstrap.gd")
const SteamIdentityProvider = preload("res://src/platform/identity/steam_identity_provider.gd")
const FakeIdentityProvider = preload("res://src/platform/identity/fake_identity_provider.gd")
const RecordingServerRegistry = preload("res://src/platform/server_registry/recording_server_registry.gd")
const HttpServerRegistry = preload("res://src/platform/server_registry/http_server_registry.gd")
const TestCase = preload("res://tests/support/test_case.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := TestCase.new()

	_test_production_selection_has_no_side_effects(t)
	_test_normal_connect_selects_steam(t)
	_test_e2e_connect_selects_readable_fake_identities(t)
	_test_e2e_server_selects_recording_registry(t)
	_test_e2e_requires_test_adapters(t)
	_test_offline_selects_fake_null(t)
	_test_invalid_role_or_dependencies_fail(t)
	_test_recording_registry_snapshot_isolation(t)
	await _test_http_registry_publishes_and_maps_status(t)
	await _test_game_manager_publishes_through_injected_registry(t)

	quit(t.finish())

func _options(args: PackedStringArray, allow_e2e := false) -> RuntimeOptions:
	return RuntimeOptions.parse(args, allow_e2e).options

func _e2e_connect_options(instance: String) -> RuntimeOptions:
	return _options(
			PackedStringArray(["connect", "127.0.0.1", "5000", "--e2e", "--e2e-instance", instance, "--e2e-control-port", "6001"]),
			true,
	)

func _test_production_selection_has_no_side_effects(t: TestCase) -> void:
	var result := Bootstrap.build(_options(PackedStringArray([])), null, false)
	t.check(result.is_ok(), "Menu client should build, got: %s" % result.error)
	if result.is_ok():
		t.check(
				result.context.identity is SteamIdentityProvider,
				"Production client must select the real Steam identity, never a fake",
		)
		t.check(result.context.server_registry == null, "A normal client needs no server registry")

func _test_normal_connect_selects_steam(t: TestCase) -> void:
	var result := Bootstrap.build(_options(PackedStringArray(["connect", "127.0.0.1", "5000"])), null, false)
	t.check(result.is_ok(), "Normal connect client should build, got: %s" % result.error)
	if result.is_ok():
		t.check(
				result.context.identity is SteamIdentityProvider,
				"Production connect client must select the real Steam identity, never a fake",
		)
		t.check(result.context.server_registry == null, "A connect client needs no server registry")

func _test_e2e_connect_selects_readable_fake_identities(t: TestCase) -> void:
	var alice := Bootstrap.build(_e2e_connect_options("alice"), null, true)
	var bob := Bootstrap.build(_e2e_connect_options("bob"), null, true)
	t.check(alice.is_ok(), "E2E connect client should build, got: %s" % alice.error)
	t.check(bob.is_ok(), "E2E connect client should build, got: %s" % bob.error)
	if alice.is_ok() and bob.is_ok():
		t.check(
				alice.context.identity is FakeIdentityProvider,
				"E2E connect must select the fake identity, never Steam",
		)
		t.check(alice.context.server_registry == null, "E2E connect client needs no server registry")
		t.check_equal(
				alice.context.identity.display_name(),
				"Alice",
				"E2E identity name should read directly from the instance",
		)
		t.check_equal(
				bob.context.identity.display_name(),
				"Bob",
				"E2E identity name should read directly from the instance",
		)
		t.check(alice.context.identity.player_id() > 0, "E2E identity must have a positive account id")
		t.check(bob.context.identity.player_id() > 0, "E2E identity must have a positive account id")
		t.check(
				alice.context.identity.player_id() != bob.context.identity.player_id(),
				"Distinct instances must get distinct account ids",
		)

		var ticket := { "value": "" }
		alice.context.identity.auth_ticket_ready.connect(func(tk: String) -> void: ticket["value"] = tk)
		alice.context.identity.request_auth_ticket()
		t.check(ticket["value"] != "", "E2E identity must deliver a nonempty auth ticket without contacting Steam")

func _test_e2e_server_selects_recording_registry(t: TestCase) -> void:
	var args := PackedStringArray([
				"server",
				"DM-1",
				"3005",
				"8",
				"deathmatch",
				"--e2e",
				"--e2e-instance",
				"srv",
				"--e2e-control-port",
				"6002",
			])
	var result := Bootstrap.build(_options(args, true), null, true)
	t.check(result.is_ok(), "E2E dedicated server should build without a bridge, got: %s" % result.error)
	if result.is_ok():
		t.check(result.context.identity == null, "E2E dedicated server needs no identity")
		t.check(
				result.context.server_registry is RecordingServerRegistry,
				"E2E dedicated server must select the recording registry",
		)

func _test_e2e_requires_test_adapters(t: TestCase) -> void:
	t.check(
			not Bootstrap.build(_e2e_connect_options("alice"), null, false).is_ok(),
			"E2E must be rejected when test adapters are not allowed",
	)

func _test_offline_selects_fake_null(t: TestCase) -> void:
	var offline := Bootstrap.build(_options(PackedStringArray(["--offline-playtest"])), null, false)
	t.check(offline.is_ok(), "Offline profile should build, got: %s" % offline.error)
	if offline.is_ok():
		t.check(
				offline.context.identity is FakeIdentityProvider,
				"Offline profile must select the fake identity, never Steam",
		)
		t.check(offline.context.server_registry == null, "Offline profile is client-only and needs no server registry")

func _test_invalid_role_or_dependencies_fail(t: TestCase) -> void:
	var server_args := PackedStringArray(["server", "DM-1", "3005", "8", "deathmatch"])
	t.check(
			not Bootstrap.build(_options(server_args), null, false).is_ok(),
			"Dedicated server without a bridge must be rejected",
	)

	var with_bridge := Bootstrap.build(_options(server_args), _FakeBridge.new(), false)
	t.check(with_bridge.is_ok(), "Dedicated server with a bridge should build, got: %s" % with_bridge.error)
	if with_bridge.is_ok():
		t.check(
				with_bridge.context.server_registry is HttpServerRegistry,
				"Dedicated server must select the HTTP registry",
		)

func _test_recording_registry_snapshot_isolation(t: TestCase) -> void:
	var registry := RecordingServerRegistry.new()
	var snapshot := { "name": "DM-1", "nested": { "players": [1, 2] } }
	registry.publish(snapshot)
	snapshot["name"] = "mutated"
	snapshot["nested"]["players"].append(3)

	var stored := registry.snapshots()
	t.check_equal(stored[0]["name"], "DM-1", "Stored snapshot must be independent of later caller mutation")
	t.check_equal((stored[0]["nested"]["players"] as Array).size(), 2, "Nested snapshot data must be deep-copied")

	stored[0]["name"] = "tampered"
	t.check_equal(registry.snapshots()[0]["name"], "DM-1", "snapshots() must hand out an independent copy each call")

func _test_http_registry_publishes_and_maps_status(t: TestCase) -> void:
	var body := { "name": "DM-1", "port": 3005, "nested": { "players": [1, 2] } }

	var ok_client := _FakeClient.new(_FakeResponse.new(200))
	var ok := await HttpServerRegistry.new(_FakeBridge.new(ok_client)).publish(body)
	t.check_equal(ok, OK, "HTTP registry must return OK on HTTP 200")
	t.check_equal(ok_client.last_path, "/browser", "HTTP registry must publish to /browser")
	t.check_equal(ok_client.last_body, body, "HTTP registry must publish the caller's snapshot verbatim")

	var bad := await HttpServerRegistry.new(_FakeBridge.new(_FakeClient.new(_FakeResponse.new(500)))).publish(body)
	t.check(bad != OK, "HTTP registry must return an explicit non-OK error on a non-200 status")

	var offline := await HttpServerRegistry.new(_FakeBridge.new(_FakeClient.new(null))).publish(body)
	t.check_equal(offline, ERR_CANT_CONNECT, "HTTP registry must return ERR_CANT_CONNECT when there is no response")

func _test_game_manager_publishes_through_injected_registry(t: TestCase) -> void:
	var GameManagerScript: GDScript = load("res://src/game_manager.gd")
	var MapManagerScript: GDScript = load("res://src/maps/map_manager.gd")
	var options := _options(PackedStringArray(["server", "DM-1", "3005", "8", "deathmatch"]))
	var registry := RecordingServerRegistry.new()
	var gm: Node = GameManagerScript.new(options, registry, MapManagerScript.new())
	root.add_child(gm)

	gm.current_pvp_map = "de_dust.tscn"
	gm.current_pvp_mode = "deathmatch"
	gm.server_name = "DM-1"
	gm.port = 3005
	gm.max_players = 8
	gm.player_count = 2

	await gm._publish_server_snapshot()

	var snapshots := registry.snapshots()
	t.check_equal(snapshots.size(), 1, "GameManager must publish exactly one snapshot through the injected registry")
	if snapshots.size() == 1:
		var snap: Dictionary = snapshots[0]
		t.check_equal(
				snap["map"],
				"de_dust",
				"GameManager must assemble the snapshot itself and strip the .tscn suffix",
		)
		t.check_equal(snap["mode"], "deathmatch", "Snapshot mode must be the live mode")
		t.check_equal(snap["name"], "DM-1", "Snapshot name must be the live server name")
		t.check_equal(snap["port"], 3005, "Snapshot port must be the live port")
		t.check_equal(snap["player_count"], 2, "Snapshot must publish the live player count")
		t.check_equal(snap["max_players"], 8, "Snapshot must publish the live max players")

	gm.queue_free()

class _FakeResponse:
	var _code: int

	func _init(code: int) -> void:
		_code = code

	func status() -> int:
		return _code

class _FakeRequest:
	var _client: _FakeClient

	func _init(client: _FakeClient) -> void:
		_client = client

	func json(object: Variant) -> _FakeRequest:
		_client.last_body = object
		return self

	func send() -> Variant:
		return _client.response

class _FakeClient:
	var response: Variant
	var last_path := ""
	var last_body: Variant

	func _init(resp: Variant) -> void:
		response = resp

	func http_post(path: String = "/") -> _FakeRequest:
		last_path = path
		return _FakeRequest.new(self)

class _FakeBridge:
	var client: Variant

	func _init(c: Variant = null) -> void:
		client = c
