class_name AimMenu
extends Control

const AIM_TRAINER_SCENE := "res://src/maps/aim/aim_trainer.tscn"
const SCENARIO_GRIDSHOT := "gridshot"
const SCENARIO_FLICK := "flick"
const SCENARIO_TRACKING := "tracking"
const SCENARIO_ORDER := [SCENARIO_GRIDSHOT, SCENARIO_FLICK, SCENARIO_TRACKING]
const LEADERBOARD_TAB_SCENARIO := 0
const LEADERBOARD_TAB_OVERALL := 1
const SCENARIO_INFO := {
	SCENARIO_GRIDSHOT: {
		"label": "Gridshot",
	},
	SCENARIO_FLICK: {
		"label": "Flick",
	},
	SCENARIO_TRACKING: {
		"label": "Tracking",
	}
}

@onready var gridshot_button: Button = $Scroll/Margin/Content/ScenarioList/GridshotOption/OptionContent/OptionStack/GridshotButton
@onready var flick_button: Button = $Scroll/Margin/Content/ScenarioList/FlickOption/OptionContent/OptionStack/FlickButton
@onready var tracking_button: Button = $Scroll/Margin/Content/ScenarioList/TrackingOption/OptionContent/OptionStack/TrackingButton
@onready var selected_scenario_label: Label = $Scroll/Margin/Content/SelectedScenarioLabel
@onready var start_button: Button = $Scroll/Margin/Content/StartButton
@onready var leaderboard_tabs: TabContainer = $Scroll/Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs
@onready var scenario_status_label: Label = $Scroll/Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs/ScenarioRankings/ScenarioLeaderboardStatus
@onready var scenario_rows: VBoxContainer = $Scroll/Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs/ScenarioRankings/ScenarioLeaderboardScroll/ScenarioLeaderboardRows
@onready var overall_status_label: Label = $Scroll/Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs/OverallRankings/OverallLeaderboardStatus
@onready var overall_rows: VBoxContainer = $Scroll/Margin/Content/LeaderboardPanel/PanelMargin/PanelContent/LeaderboardTabs/OverallRankings/OverallLeaderboardScroll/OverallLeaderboardRows

var selected_scenario := SCENARIO_GRIDSHOT
var scenario_request_generation := 0
var overall_request_generation := 0
var scenario_buttons: Dictionary = {}

func _ready() -> void:
	scenario_buttons = {
		SCENARIO_GRIDSHOT: gridshot_button,
		SCENARIO_FLICK: flick_button,
		SCENARIO_TRACKING: tracking_button,
	}
	gridshot_button.pressed.connect(_on_scenario_pressed.bind(SCENARIO_GRIDSHOT))
	flick_button.pressed.connect(_on_scenario_pressed.bind(SCENARIO_FLICK))
	tracking_button.pressed.connect(_on_scenario_pressed.bind(SCENARIO_TRACKING))
	start_button.pressed.connect(_start_session)
	leaderboard_tabs.tab_changed.connect(_on_leaderboard_tab_changed)

	selected_scenario = Global.game_manager.get_current_aim_scenario()
	_apply_selected_scenario(false)
	_refresh_scenario_leaderboard()
	_refresh_overall_leaderboard()

func _on_scenario_pressed(scenario: String) -> void:
	selected_scenario = scenario
	_apply_selected_scenario(true)

func _apply_selected_scenario(refresh_leaderboard: bool) -> void:
	Global.game_manager.current_aim_scenario = selected_scenario
	for scenario in SCENARIO_ORDER:
		var button: Button = scenario_buttons[scenario]
		button.button_pressed = scenario == selected_scenario

	var info: Dictionary = SCENARIO_INFO[selected_scenario]
	selected_scenario_label.text = "Selected Scenario: %s" % info["label"]
	if refresh_leaderboard:
		_refresh_scenario_leaderboard()

func _start_session() -> void:
	get_tree().change_scene_to_file(AIM_TRAINER_SCENE)

func _on_leaderboard_tab_changed(tab_index: int) -> void:
	if tab_index == LEADERBOARD_TAB_SCENARIO:
		_refresh_scenario_leaderboard()
		return
	_refresh_overall_leaderboard()

func _refresh_scenario_leaderboard() -> void:
	scenario_request_generation += 1
	var generation := scenario_request_generation
	_clear_rows(scenario_rows)
	var info: Dictionary = SCENARIO_INFO[selected_scenario]
	scenario_status_label.text = "Loading %s leaderboard..." % info["label"]

	var response = await Global.server_bridge.get_aim_scores(selected_scenario, 1)
	if not _can_apply_scenario_request(generation):
		return
	if response == null:
		scenario_status_label.text = "%s leaderboard unavailable." % info["label"]
		return
	if response.scores.is_empty():
		scenario_status_label.text = "No %s scores yet." % String(info["label"]).to_lower()
		return

	scenario_status_label.text = "Showing top %d of %d %s scores" % [response.scores.size(), response.total, info["label"]]
	_populate_scenario_rows(response.scores)

func _refresh_overall_leaderboard() -> void:
	overall_request_generation += 1
	var generation := overall_request_generation
	_clear_rows(overall_rows)
	overall_status_label.text = "Loading overall leaderboard..."

	var scores = await Global.server_bridge.get_aim_overall_leaderboard()
	if not _can_apply_overall_request(generation):
		return
	if scores.is_empty():
		if Global.server_bridge.last_aim_overall_leaderboard_available:
			overall_status_label.text = "No overall aim scores yet."
		else:
			overall_status_label.text = "Overall leaderboard unavailable."
		return

	overall_status_label.text = "Showing top %d overall aim players" % scores.size()
	_populate_overall_rows(scores)

func _can_apply_scenario_request(generation: int) -> bool:
	return is_inside_tree() and generation == scenario_request_generation

func _can_apply_overall_request(generation: int) -> bool:
	return is_inside_tree() and generation == overall_request_generation

func _populate_scenario_rows(scores: Array) -> void:
	var data_rows: Array = []
	for entry in scores:
		data_rows.append([
			"#%d" % entry.position,
			entry.username,
			str(entry.score),
			"%.1f%%" % entry.accuracy,
			_format_reaction(entry.avg_reaction_ms),
		])
	_build_leaderboard_grid(scenario_rows, ["#", "Player", "Score", "Accuracy", "Reaction"], data_rows, 1)

func _populate_overall_rows(scores: Array) -> void:
	var data_rows: Array = []
	var rank := 1
	for entry in scores:
		data_rows.append([
			"#%d" % rank,
			entry.username,
			str(entry.total_score),
			str(entry.scenarios_completed),
			"%.1f%%" % entry.accuracy,
			_format_reaction(entry.avg_reaction_ms),
		])
		rank += 1
	_build_leaderboard_grid(overall_rows, ["#", "Player", "Total", "Scenarios", "Accuracy", "Reaction"], data_rows, 1)

func _build_leaderboard_grid(container: VBoxContainer, columns: Array, data_rows: Array, expand_index: int) -> void:
	_clear_rows(container)
	var grid := GridContainer.new()
	grid.columns = columns.size()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)

	for index in range(columns.size()):
		grid.add_child(_create_cell(str(columns[index]), index, expand_index, true))

	for row in data_rows:
		for index in range(row.size()):
			grid.add_child(_create_cell(str(row[index]), index, expand_index, false))

	container.add_child(grid)

func _create_cell(text: String, index: int, expand_index: int, is_header: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if index == expand_index else Control.SIZE_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if index <= expand_index else HORIZONTAL_ALIGNMENT_RIGHT
	if is_header:
		label.add_theme_font_size_override("font_size", 15)
		label.modulate = Color(0.72, 0.78, 0.84, 1.0)
	else:
		label.add_theme_font_size_override("font_size", 17)
	return label

func _format_reaction(avg_reaction_ms: float) -> String:
	if is_zero_approx(avg_reaction_ms):
		return "--"
	return "%d ms" % int(round(avg_reaction_ms))

func _clear_rows(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
