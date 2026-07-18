extends SceneTree

const ROOFTOPS_SCENE := "res://src/maps/speedrun/map_rooftops.tscn"
const TestCase = preload("res://tests/support/test_case.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := TestCase.new()
	await _wait_for_app_context()
	for _frame in range(5):
		await process_frame

	if current_scene != null:
		current_scene.free()
		current_scene = null
	await physics_frame

	var rooftops_scene := load(ROOFTOPS_SCENE) as PackedScene
	t.check(rooftops_scene != null, "Rooftops should load for the grounding regression test")
	if rooftops_scene == null:
		quit(t.finish())
		return

	var rooftops := rooftops_scene.instantiate()
	var map: Node3D = rooftops.get_node("Map")
	var player = rooftops.get_node("Player")
	rooftops.remove_child(map)
	rooftops.remove_child(player)
	rooftops.free()
	for child in map.get_children():
		if child is Area3D:
			if "audio_player" in child and is_instance_valid(child.audio_player):
				child.audio_player.free()
			child.free()
	root.add_child(map)
	root.add_child(player)
	player.setup_as_local_player()
	player.set_physics_process(false)
	player._time_since_last_run_sound = -100.0
	await physics_frame

	var missed_floor_contact := false
	for frame in range(60):
		var input := Vector2(0, -1) if frame < 30 else Vector2.ZERO
		player._movement_process(1.0 / 60.0, input, false)
		if player.is_on_floor() and not player.grounded():
			missed_floor_contact = true
		await physics_frame

	t.check(
			not missed_floor_contact,
			"Grounded state should include floor contacts reported by CharacterBody3D",
	)
	player._run_audio_player.stop()
	player._run_audio_player.stream = null
	player.free()
	map.free()
	await process_frame
	quit(t.finish())

func _wait_for_app_context() -> void:
	for _frame in range(600):
		var global_node := root.get_node_or_null("Global")
		if global_node != null and global_node.context != null:
			return
		await process_frame
