extends SceneTree

const AIM_MENU_SCENE_PATH := "res://src/menus/main/aim_menu.tscn"
const MAIN_MENU_SCENE_PATH := "res://src/menus/main/main_menu.tscn"

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var aim_menu_scene := load(AIM_MENU_SCENE_PATH) as PackedScene
	_check(aim_menu_scene != null, "Expected %s to load" % AIM_MENU_SCENE_PATH)
	var aim_menu = aim_menu_scene.instantiate() if aim_menu_scene != null else null
	if aim_menu != null:
		_check(aim_menu.has_node("Scroll/Margin/Content/ScenarioList"), "Aim menu should expose scenario selectors")
		_check(
				aim_menu.has_node("Scroll/Margin/Content/SelectedScenarioLabel"),
				"Aim menu should expose the selected scenario summary",
		)
		_check(
				aim_menu.has_node("Scroll/Margin/Content/StartButton"),
				"Aim menu should expose the session start button",
		)
		_check(
				aim_menu.has_node("Scroll/Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs"),
				"Aim menu should expose leaderboard tabs",
		)
		_check(
				aim_menu.has_node(
						(
							"Scroll/Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs" + "/ScenarioRankings/ScenarioLeaderboardScroll/ScenarioLeaderboardRows"
						)
				),
				"Aim menu should expose scenario leaderboard rows",
		)
		_check(
				aim_menu.has_node(
						(
							"Scroll/Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs" + "/OverallRankings/OverallLeaderboardScroll/OverallLeaderboardRows"
						)
				),
				"Aim menu should expose overall leaderboard rows",
		)
		root.add_child(aim_menu)
		await process_frame
		var leaderboard_tabs = aim_menu.get_node("Scroll/Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs")
		_check(leaderboard_tabs is TabContainer, "Aim menu leaderboard view should be a TabContainer")
		_check(leaderboard_tabs.get_tab_count() == 2, "Aim menu should expose scenario and overall leaderboard tabs")

	var main_menu_scene := load(MAIN_MENU_SCENE_PATH) as PackedScene
	_check(main_menu_scene != null, "Expected %s to load" % MAIN_MENU_SCENE_PATH)
	var main_menu = main_menu_scene.instantiate() if main_menu_scene != null else null
	if main_menu != null:
		_check(
				main_menu.has_node("MarginContainer/Content/Body/Aim Trainer"),
				"Main menu should expose an Aim Trainer tab",
		)
		var speedrun_modes_path := "MarginContainer/Content/Body/Speedrun/M/V/ModeSwitcher"
		var speedrun_leaderboard_path := speedrun_modes_path + "/Leaderboard"
		var target_leaderboard_path := speedrun_leaderboard_path + "/Overall/H/VBoxContainer/TargetPracticeLeaderboard"
		var movement_leaderboard_path := speedrun_leaderboard_path + "/Overall/H/VBoxContainer2/MovementOnlyLeaderboard"
		var speedrun_modes = main_menu.get_node(speedrun_modes_path)
		_check(
				speedrun_modes.get_tab_count() == 3,
				"Speedrun should expose Target Practice, Movement Only, and Leaderboard tabs",
		)
		_check(
				main_menu.has_node(speedrun_leaderboard_path),
				"Speedrun should expose a dedicated leaderboard mode tab",
		)
		_check(
				main_menu.has_node(target_leaderboard_path),
				"Speedrun leaderboard tab should expose Target Practice rankings",
		)
		_check(
				main_menu.has_node(movement_leaderboard_path),
				"Speedrun leaderboard tab should expose Movement Only rankings",
		)
		_check(
				not main_menu.has_node("MarginContainer/Content/Body/Leaderboard"),
				"Main menu should not expose a separate Leaderboard tab",
		)

	var global_node = root.get_node_or_null("Global")
	_check(global_node != null, "Global autoload should exist during the smoke test")
	var runtime_bridge = global_node.server_bridge if global_node != null else null
	_check(runtime_bridge != null, "Global should initialize a ServerBridge instance")

	if is_instance_valid(aim_menu):
		aim_menu.free()
	if is_instance_valid(main_menu):
		main_menu.free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
