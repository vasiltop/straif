extends SceneTree

const PLAYER_SCENE_PATH := "res://src/player/player.tscn"

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	_check(player_scene != null, "Expected player scene to load")
	var player = player_scene.instantiate() if player_scene != null else null
	_check(player != null, "Expected player scene to instantiate")
	if player != null:
		root.add_child(player)
		await process_frame

		player.third_person.visible = false
		player.weapon_handler.visible = true
		player.set_viewmodel_viewport_visible(true)

		player._show_local_ragdoll_view()

		_check(player.ragdoll_camera.is_current(), "Ragdoll camera should become current")
		_check(player.third_person.visible, "Third-person body should remain visible")
		_check(not player.weapon_handler.visible, "Weapon handler should be hidden")
		_check(not player.gun_vp_container.visible, "Gun viewport container should be hidden")

		player._show_local_first_person_view()

		_check(player.camera.is_current(), "Camera should become current again")
		_check(player.gun_camera.is_current(), "Gun camera should become current again")
		_check(not player.third_person.visible, "Third-person body should hide again")
		_check(player.weapon_handler.visible, "Weapon handler should show again")
		_check(player.gun_vp_container.visible, "Gun viewport container should show again")

		player.queue_free()

	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
