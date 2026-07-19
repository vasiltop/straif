class_name LeaderboardMenu extends Control

const CATEGORIES := [
	["target", "Target Practice"],
	["bhop", "Movement Only"],
	["gridshot", "Gridshot"],
	["flick", "Flick"],
	["tracking", "Tracking"],
	["overall", "Overall"],
]

@onready var select: HBoxContainer = $Scroll/Margin/Content/Select
@onready var status: Label = $Scroll/Margin/Content/Status
@onready var rows: VBoxContainer = $Scroll/Margin/Content/Rows

var buttons: Array[Button] = []
var current := 0
var generation := 0

func _ready() -> void:
	var group := ButtonGroup.new()
	for i in CATEGORIES.size():
		var btn := Button.new()
		btn.text = CATEGORIES[i][1]
		btn.toggle_mode = true
		btn.button_group = group
		btn.theme_type_variation = &"Segment"
		btn.focus_mode = Control.FOCUS_NONE
		btn.button_pressed = i == 0
		btn.pressed.connect(_select.bind(i))
		select.add_child(btn)
		buttons.append(btn)
	visibility_changed.connect(_on_visibility_changed)
	_select(0)

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh()

func _select(index: int) -> void:
	current = index
	buttons[index].button_pressed = true
	_refresh()

func _refresh() -> void:
	var id: String = CATEGORIES[current][0]
	var label: String = CATEGORIES[current][1]
	if id == "target" or id == "bhop":
		await _refresh_mode(id, label)
	elif id == "overall":
		await _refresh_overall()
	else:
		await _refresh_scenario(id, label)

func _refresh_mode(mode: String, label: String) -> void:
	generation += 1
	var gen := generation
	_clear()
	status.text = "Loading %s leaderboard..." % label
	var lb: Array = await Global.server_bridge.get_overall_leaderboard(mode)
	if not _valid(gen):
		return
	if lb.is_empty():
		status.text = "No %s scores yet." % label.to_lower()
		return
	var data: Array = []
	var rank := 1
	for run in lb:
		data.append(["#%d" % rank, run.username, _fmt(int(run.points))])
		rank += 1
	status.text = "Showing top %d %s players" % [data.size(), label]
	_build_grid(["#", "Player", "Points"], data)

func _refresh_scenario(scenario: String, label: String) -> void:
	generation += 1
	var gen := generation
	_clear()
	status.text = "Loading %s leaderboard..." % label
	var response = await Global.server_bridge.get_aim_scores(scenario, 1)
	if not _valid(gen):
		return
	if response == null:
		status.text = "%s leaderboard unavailable." % label
		return
	if response.scores.is_empty():
		status.text = "No %s scores yet." % label.to_lower()
		return
	var data: Array = []
	for entry in response.scores:
		data.append([
					"#%d" % entry.position,
					entry.username,
					_fmt(int(entry.score)),
					"%.1f%%" % entry.accuracy,
					_format_reaction(entry.avg_reaction_ms),
				])
	status.text = "Showing top %d of %d %s scores" % [data.size(), response.total, label]
	_build_grid(["#", "Player", "Score", "Accuracy", "Reaction"], data)

func _refresh_overall() -> void:
	generation += 1
	var gen := generation
	_clear()
	status.text = "Loading overall leaderboard..."
	var scores = await Global.server_bridge.get_aim_overall_leaderboard()
	if not _valid(gen):
		return
	if scores.is_empty():
		if Global.server_bridge.last_aim_overall_leaderboard_available:
			status.text = "No overall aim scores yet."
		else:
			status.text = "Overall leaderboard unavailable."
		return
	var data: Array = []
	var rank := 1
	for entry in scores:
		data.append(
				[
					"#%d" % rank,
					entry.username,
					_fmt(int(entry.total_score)),
					str(entry.scenarios_completed),
					"%.1f%%" % entry.accuracy,
					_format_reaction(entry.avg_reaction_ms),
				]
		)
		rank += 1
	status.text = "Showing top %d overall aim players" % data.size()
	_build_grid(["#", "Player", "Total", "Scenarios", "Accuracy", "Reaction"], data)

func _valid(gen: int) -> bool:
	return is_inside_tree() and gen == generation

func _build_grid(columns: Array, data_rows: Array) -> void:
	_clear()
	var grid := GridContainer.new()
	grid.columns = columns.size()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	for index in range(columns.size()):
		grid.add_child(_create_cell(str(columns[index]), index, true))
	for row in data_rows:
		for index in range(row.size()):
			grid.add_child(_create_cell(str(row[index]), index, false))
	rows.add_child(grid)

func _create_cell(text: String, index: int, is_header: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if index == 1 else Control.SIZE_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if index <= 1 else HORIZONTAL_ALIGNMENT_RIGHT
	if is_header:
		label.theme_type_variation = &"Eyebrow"
	elif index == 1:
		label.theme_type_variation = &"BodyStrong"
	else:
		label.theme_type_variation = &"Data"
	return label

func _format_reaction(avg_reaction_ms: float) -> String:
	if is_zero_approx(avg_reaction_ms):
		return "--"
	return "%d ms" % int(round(avg_reaction_ms))

func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

func _clear() -> void:
	for child in rows.get_children():
		child.queue_free()
