extends SceneTree

const AIM_MENU_SCENE_PATH := "res://src/menus/main/aim_menu.tscn"
const MAIN_MENU_SCENE_PATH := "res://src/menus/main/main_menu.tscn"
const SERVER_BRIDGE_SCRIPT_PATH := "res://src/server_bridge.gd"

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var aim_menu_scene := load(AIM_MENU_SCENE_PATH) as PackedScene
	_check(aim_menu_scene != null, "Expected %s to load" % AIM_MENU_SCENE_PATH)
	var aim_menu = aim_menu_scene.instantiate() if aim_menu_scene != null else null
	if aim_menu != null:
		_check(aim_menu.has_node("Margin/Content/ScenarioList"), "Aim menu should expose scenario selectors")
		_check(aim_menu.has_node("Margin/Content/SelectedScenarioLabel"), "Aim menu should expose the selected scenario summary")
		_check(aim_menu.has_node("Margin/Content/StartButton"), "Aim menu should expose the session start button")
		_check(aim_menu.has_node("Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs"), "Aim menu should expose leaderboard tabs")
		_check(aim_menu.has_node("Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs/ScenarioRankings/ScenarioLeaderboardScroll/ScenarioLeaderboardRows"), "Aim menu should expose scenario leaderboard rows")
		_check(aim_menu.has_node("Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs/OverallRankings/OverallLeaderboardScroll/OverallLeaderboardRows"), "Aim menu should expose overall leaderboard rows")
		root.add_child(aim_menu)
		await process_frame
		var leaderboard_tabs = aim_menu.get_node("Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs")
		_check(leaderboard_tabs is TabContainer, "Aim menu leaderboard view should be a TabContainer")
		_check(leaderboard_tabs.get_tab_count() == 2, "Aim menu should expose scenario and overall leaderboard tabs")

	var main_menu_scene := load(MAIN_MENU_SCENE_PATH) as PackedScene
	_check(main_menu_scene != null, "Expected %s to load" % MAIN_MENU_SCENE_PATH)
	var main_menu = main_menu_scene.instantiate() if main_menu_scene != null else null
	if main_menu != null:
		_check(main_menu.has_node("MarginContainer/Content/Body/Aim Trainer"), "Main menu should expose an Aim Trainer tab")

	var bridge_file := FileAccess.open(SERVER_BRIDGE_SCRIPT_PATH, FileAccess.READ)
	_check(bridge_file != null, "Expected %s to open" % SERVER_BRIDGE_SCRIPT_PATH)
	var global_node = root.get_node_or_null("Global")
	_check(global_node != null, "Global autoload should exist during the smoke test")
	var runtime_bridge = global_node.server_bridge if global_node != null else null
	_check(runtime_bridge != null, "Global should initialize a ServerBridge instance")
	if runtime_bridge != null:
		_check(runtime_bridge.has_method("submit_aim_score"), "ServerBridge should expose submit_aim_score")
		_check(runtime_bridge.has_method("get_aim_scores"), "ServerBridge should expose get_aim_scores")
		_check(runtime_bridge.has_method("get_aim_overall_leaderboard"), "ServerBridge should expose get_aim_overall_leaderboard")
	if bridge_file != null:
		var bridge_source := bridge_file.get_as_text()
		_check(bridge_source.contains("class AimScoreEntry"), "ServerBridge should define AimScoreEntry")
		_check(bridge_source.contains("class AimScoresResponse"), "ServerBridge should define AimScoresResponse")
		_check(bridge_source.contains("class AimOverallEntry"), "ServerBridge should define AimOverallEntry")
		_check(bridge_source.contains("class AimScoreSubmissionResult"), "ServerBridge should define AimScoreSubmissionResult")
		_check(bridge_source.contains("avg_reaction_ms: int"), "ServerBridge submit_aim_score should require integer avg_reaction_ms")
		_check(not bridge_source.contains("theme_override_constants."), "ServerBridge should not use invalid theme override dot access")
		_check(not bridge_source.contains("theme_override_font_sizes."), "ServerBridge should not use invalid theme override font-size dot access")

	var aim_menu_script_file := FileAccess.open("res://src/menus/main/aim_menu.gd", FileAccess.READ)
	_check(aim_menu_script_file != null, "Expected aim_menu.gd to open")
	if aim_menu_script_file != null:
		var aim_menu_source := aim_menu_script_file.get_as_text()
		_check(not aim_menu_source.contains("theme_override_constants."), "AimMenu should avoid invalid theme override dot access")
		_check(not aim_menu_source.contains("theme_override_font_sizes."), "AimMenu should avoid invalid theme override font-size dot access")

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
