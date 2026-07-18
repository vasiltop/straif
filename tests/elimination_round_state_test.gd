extends SceneTree

const PLAYER_SCENE_PATH := "res://src/player/player.tscn"
const AK47_PATH := "res://src/player/weapon/resources/ak47.tres"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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

	player.set_damage_enabled(true)
	player._apply_authoritative_damage(34.0, "test", 2)
	_check(is_equal_approx(player.health, 66.0), "Enabled authoritative damage should reduce health")

	player.set_damage_enabled(false)
	player.health = 100.0
	player._apply_authoritative_damage(34.0, "test", 2)
	_check(is_equal_approx(player.health, 100.0), "Damage disabled during freeze should ignore a late hit")

	player.is_dead = false
	player.third_person.visible = true
	player.refresh_view_visibility()
	_check(not player.third_person.visible, "An alive local player should never render its third-person body")

	var remote_player = player_scene.instantiate()
	root.add_child(remote_player)
	await process_frame
	remote_player.pid = 2
	remote_player.weapon_handler.set_weapon(ak47, true)
	remote_player.begin_local_spectate_view()
	_check(not remote_player.third_person.visible, "A spectated remote player should hide its body in first person")
	remote_player.end_local_spectate_view()
	_check(remote_player.third_person.visible, "A remote player should restore its body after spectating ends")
	remote_player.free()

	player.free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
