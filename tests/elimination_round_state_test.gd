extends SceneTree

const PLAYER_SCENE_PATH := "res://src/player/player.tscn"
const AK47_PATH := "res://src/player/weapon/resources/ak47.tres"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var elimination_file := FileAccess.open(
		"res://src/maps/elimination.gd",
		FileAccess.READ
	)
	_check(elimination_file != null, "Expected elimination.gd to open")
	if elimination_file != null:
		var elimination_source := elimination_file.get_as_text()
		_check(
			elimination_source.contains("player.respawn.rpc(false)"),
			"Elimination freeze should respawn players with damage disabled"
		)
		_check(
			elimination_source.contains("player.set_damage_enabled.rpc(true)"),
			"Elimination LIVE should explicitly enable player damage"
		)
		_check(
			elimination_source.contains(
				"get_player(sender).set_damage_enabled.rpc(phase == Phase.LIVE)"
			),
			"Players joining outside LIVE should start with damage disabled"
		)

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var ak47 := load(AK47_PATH)
	_check(player_scene != null, "Expected the player scene to load")
	_check(ak47 != null, "Expected the AK-47 resource to load")
	if player_scene == null or ak47 == null:
		quit(1)
		return

	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	player.pid = 1
	player.weapon_handler.set_weapon(ak47, false)

	_check(
		player.has_method("set_damage_enabled"),
		"Player should expose authoritative damage gating"
	)
	_check(
		player.has_method("_apply_authoritative_damage"),
		"Player should expose a single authoritative damage path"
	)
	_check(
		player.has_method("refresh_view_visibility"),
		"Player should derive local body visibility from view state"
	)

	if (
		player.has_method("set_damage_enabled")
		and player.has_method("_apply_authoritative_damage")
	):
		player.set_damage_enabled(true)
		player._apply_authoritative_damage(34.0, "test", 2)
		_check(
			is_equal_approx(player.health, 66.0),
			"Enabled authoritative damage should reduce health"
		)

		player.set_damage_enabled(false)
		player.health = 100.0
		player._apply_authoritative_damage(34.0, "test", 2)
		_check(
			is_equal_approx(player.health, 100.0),
			"Damage disabled during freeze should ignore a late hit"
		)

	if player.has_method("refresh_view_visibility"):
		player.is_dead = false
		player.third_person.visible = true
		player.refresh_view_visibility()
		_check(
			not player.third_person.visible,
			"An alive local player should never render its third-person body"
		)

		var remote_player = player_scene.instantiate()
		root.add_child(remote_player)
		await process_frame
		remote_player.pid = 2
		remote_player.weapon_handler.set_weapon(ak47, true)
		remote_player.begin_local_spectate_view()
		_check(
			not remote_player.third_person.visible,
			"A spectated remote player should hide its body in first person"
		)
		remote_player.end_local_spectate_view()
		_check(
			remote_player.third_person.visible,
			"A remote player should restore its body after spectating ends"
		)
		remote_player.free()

	player.free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
