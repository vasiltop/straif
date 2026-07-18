extends SceneTree

const AIM_TARGET_SCENE_PATH := "res://src/maps/aim/aim_target.tscn"
const AIM_TRAINER_SCENE_PATH := "res://src/maps/aim/aim_trainer.tscn"

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var aim_target_scene := load(AIM_TARGET_SCENE_PATH) as PackedScene
	_check(aim_target_scene != null, "Expected %s to load" % AIM_TARGET_SCENE_PATH)
	var aim_target = aim_target_scene.instantiate() if aim_target_scene != null else null
	if aim_target != null:
		_check(aim_target is StaticBody3D, "Aim target root should be StaticBody3D")
		_check(aim_target.is_in_group("aim_target"), "Aim target should join the aim_target group")
		_check(aim_target.has_node("CollisionShape3D"), "Aim target should have CollisionShape3D")
		_check(aim_target.has_node("Visual"), "Aim target should have a Visual node")

	var aim_trainer_scene := load(AIM_TRAINER_SCENE_PATH) as PackedScene
	_check(aim_trainer_scene != null, "Expected %s to load" % AIM_TRAINER_SCENE_PATH)
	var aim_trainer = aim_trainer_scene.instantiate() if aim_trainer_scene != null else null
	if aim_trainer != null:
		_check(aim_trainer is Node3D, "Aim trainer root should be Node3D")
		_check(aim_trainer.has_node("PlayerSpawn"), "Aim trainer should expose a player spawn marker")
		_check(aim_trainer.has_node("AimTargets"), "Aim trainer should own an AimTargets node")
		_check(aim_trainer.has_node("HUD"), "Aim trainer should own a HUD node")
		_check(
				aim_trainer.has_node("HUD/ResultsPanel/LeaderboardScroll/LeaderboardRows"),
				"Aim trainer should expose bounded leaderboard rows",
		)
		_check(
				is_equal_approx(aim_trainer.calculate_accuracy(0, 0), 0.0),
				"Accuracy helper should avoid divide-by-zero",
		)
		_check(
				is_equal_approx(aim_trainer.calculate_average_reaction_ms([0.2, 0.3]), 250.0),
				"Average reaction helper should convert seconds to milliseconds",
		)
		root.add_child(aim_trainer)
		await process_frame
		var accuracy_label := aim_trainer.get_node("HUD/SecondaryPanel/VBoxContainer/AccuracyLabel") as Label
		var reaction_label := aim_trainer.get_node("HUD/SecondaryPanel/VBoxContainer/ReactionLabel") as Label
		_check(accuracy_label.size.y >= 42.0, "Accuracy HUD label should fit two text lines")
		_check(reaction_label.size.y >= 42.0, "Reaction HUD label should fit two text lines")
		var leaderboard_status := aim_trainer.get_node("HUD/ResultsPanel/LeaderboardStatus") as Label
		var leaderboard_scroll := aim_trainer.get_node_or_null("HUD/ResultsPanel/LeaderboardScroll") as ScrollContainer
		var retry_button := aim_trainer.get_node("HUD/ResultsPanel/RetryButton") as Button
		if leaderboard_scroll != null:
			_check(
					leaderboard_status.get_rect().end.y <= leaderboard_scroll.get_rect().position.y,
					"Results status should end before leaderboard rows",
			)
			_check(
					leaderboard_scroll.get_rect().end.y <= retry_button.get_rect().position.y,
					"Leaderboard rows should end before result actions",
			)
		_check(aim_trainer.has_node("Player"), "Aim trainer should spawn a Player at runtime")
		var spawned_player = aim_trainer.get_node("Player")
		_check(
				spawned_player.weapon_handler.audio.get_parent() == spawned_player.weapon_handler,
				"Weapon handler audio should remain owned by the weapon handler after spawn",
		)
		aim_trainer.show_leaderboard_rows(
				[{ "rank": 1, "name": "Tester", "score": 1000, "accuracy": "95.0%", "reaction": "240 ms" }]
		)
		_check(
				aim_trainer.get_node("HUD/ResultsPanel/LeaderboardScroll/LeaderboardRows").get_child_count() == 1,
				"Aim trainer should create leaderboard rows at runtime",
		)
		aim_trainer.session_finished = true
		spawned_player.can_move = true
		spawned_player.can_turn = false
		spawned_player.pause_menu.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		spawned_player.toggle_pause()
		await process_frame
		_check(spawned_player.pause_menu.visible == false, "Finished-session close path should still close pause menu")
		_check(spawned_player.can_move == false, "Finished sessions should keep movement disabled")
		_check(spawned_player.can_turn == false, "Finished sessions should keep turning disabled after pause closes")
		_check(
				Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
				"Finished sessions should keep the mouse visible after pause closes",
		)

	if is_instance_valid(aim_target):
		aim_target.free()
	if is_instance_valid(aim_trainer):
		aim_trainer.free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
