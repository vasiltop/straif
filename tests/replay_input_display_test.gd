extends SceneTree

const TestCase = preload("res://tests/support/test_case.gd")
const SCENE_PATH := "res://src/maps/replay_input_display.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := TestCase.new()

	var replay_input_display_scene := load(SCENE_PATH) as PackedScene
	t.check(replay_input_display_scene != null, "Expected %s to load" % SCENE_PATH)
	if replay_input_display_scene != null:
		var replay_input_display = replay_input_display_scene.instantiate()
		t.check(replay_input_display != null, "Expected %s to instantiate" % SCENE_PATH)
		if replay_input_display != null:
			t.check(
					replay_input_display.has_method("set_inputs"),
					"Replay input display should expose set_inputs(bool, bool, bool, bool, bool, bool, bool)",
			)
			t.check(replay_input_display.has_method("reset"), "Replay input display should expose reset()")
			t.check(
					replay_input_display.has_method("is_input_active"),
					"Replay input display should expose is_input_active(StringName)",
			)

			root.add_child(replay_input_display)
			await process_frame

			_check_label(t, replay_input_display, "Movement/W/Label", "W")
			_check_label(t, replay_input_display, "Movement/A/Label", "A")
			_check_label(t, replay_input_display, "Movement/S/Label", "S")
			_check_label(t, replay_input_display, "Movement/D/Label", "D")
			_check_label(t, replay_input_display, "Combat/Shoot/Label", "LMB")
			_check_label(t, replay_input_display, "Combat/Ads/Label", "RMB")
			_check_label(t, replay_input_display, "Combat/Reload/Label", "R")

			replay_input_display.set_inputs(true, false, true, false, true, false, true)
			_check_input_state(t, replay_input_display, &"forward", true)
			_check_input_state(t, replay_input_display, &"left", true)
			_check_input_state(t, replay_input_display, &"back", false)
			_check_input_state(t, replay_input_display, &"right", false)
			_check_input_state(t, replay_input_display, &"shoot", true)
			_check_input_state(t, replay_input_display, &"ads", false)
			_check_input_state(t, replay_input_display, &"reload", true)

			var active_panel := _panel_stylebox(replay_input_display, "Movement/W/Label")
			var inactive_panel := _panel_stylebox(replay_input_display, "Movement/S/Label")
			t.check(active_panel != null, "Active keycap should expose a panel stylebox")
			t.check(inactive_panel != null, "Inactive keycap should expose a panel stylebox")
			if active_panel is StyleBoxFlat and inactive_panel is StyleBoxFlat:
				t.check(
						active_panel.bg_color != inactive_panel.bg_color,
						"Active and inactive keycaps should use distinct panel background colors",
				)

			replay_input_display.reset()
			_check_input_state(t, replay_input_display, &"forward", false)
			_check_input_state(t, replay_input_display, &"left", false)
			_check_input_state(t, replay_input_display, &"back", false)
			_check_input_state(t, replay_input_display, &"right", false)
			_check_input_state(t, replay_input_display, &"shoot", false)
			_check_input_state(t, replay_input_display, &"ads", false)
			_check_input_state(t, replay_input_display, &"reload", false)

			replay_input_display.queue_free()

	await process_frame
	quit(t.finish())

func _check_label(t: TestCase, replay_input_display: Node, path: String, expected_text: String) -> void:
	var label := replay_input_display.get_node_or_null(path) as Label
	t.check(label != null, "Expected %s to exist" % path)
	if label != null:
		t.check_equal(label.text, expected_text, "%s should display %s" % [path, expected_text])

func _check_input_state(t: TestCase, replay_input_display: Node, input_name: StringName, expected_active: bool) -> void:
	t.check_equal(
			replay_input_display.is_input_active(input_name),
			expected_active,
			"Replay input %s should be %s" % [input_name, "active" if expected_active else "inactive"],
	)

func _panel_stylebox(replay_input_display: Node, label_path: String) -> StyleBox:
	var label := replay_input_display.get_node_or_null(label_path) as Label
	if label == null:
		return null

	var parent_control := label.get_parent() as Control
	return parent_control.get_theme_stylebox("panel") if parent_control != null else null
