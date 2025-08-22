class_name Leaderboard extends PanelContainer

signal ghost_enabled(steam_id: int)

@onready var t_rows: GridContainer = $M/V/TRows
@onready var map_name_label: Label = $M/V/MapName
@onready var dec_page_btn: Button = $"M/V/H/<"
@onready var inc_page_btn: Button = $"M/V/H/>"
@onready var page_label: Label = $M/V/H/Page
@onready var middle: HBoxContainer = $".."
@onready var player: Player = $"../../../.."
@onready var admin_panel: PanelContainer = $"../Admin"
@onready var admin_actions_container: VBoxContainer = $"../Admin/M/V/V"
@onready var replay_last_run: Button = $M/V/ReplayLastRun
@onready var set_start_position: Button = $M/V/SetStartPosition

@onready var medal_time_labels: Array[Label] = [
	$M/V/MedalInfo/BronzeTime,
	$M/V/MedalInfo/SilverTime,
	$M/V/MedalInfo/GoldTime,
	$M/V/MedalInfo/PlatTime,
	$M/V/MedalInfo/AuthorTime
]

const PAGE_SIZE := 10.0
const MAX_NAME_LENGTH := 15

var current_page := 1
var total_pages := 1

func modify_page(value: int) -> void:
	var old := current_page
	current_page += value
	current_page = clamp(current_page, 1, total_pages)
	
	if current_page != old:
		_load_runs()

func _ready() -> void:
	dec_page_btn.pressed.connect(func() -> void: modify_page(-1))
	inc_page_btn.pressed.connect(func() -> void: modify_page(1))
	middle.visible = false
	_setup()
	
	replay_last_run.pressed.connect(
		func() -> void:
			if player.map.recorder.frames.size() <= 0:
				Info.alert("Cannot play empty recording.")
				return
			var replay := player.map.recorder.to_hex()
			Global.game_manager.replay_requested.emit(replay)
	)
	
	set_start_position.pressed.connect(
		func() -> void:
			if not player.map.completed and not player.map.running:
				player.map.start_pos = player.global_position
				player.map.start_rotation = player.camera._input_rotation
	)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("leaderboard"):
		middle.visible = true
		
		if Global.game_manager.admin and Input.is_action_pressed("ui_admin"):
			admin_panel.visible = true

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_setup()
	elif Input.is_action_just_released("leaderboard"):
		middle.visible = false
		admin_panel.visible = false
		
		if not player.map.is_watching_replay():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _load_runs() -> void:
	var response := await Global.server_bridge.get_runs(Global.game_manager.current_mode, Global.game_manager.current_map.name, current_page)
	var my_run := await Global.server_bridge.get_my_run_by_map(Global.game_manager.current_mode, Global.game_manager.current_map.name)
	
	total_pages = max(1, ceil(response.total / PAGE_SIZE))
	page_label.text = "Page %d of %d" % [current_page, total_pages]
	
	var runs := response.runs
	var run_position := (current_page - 1) * PAGE_SIZE + 1
	
	for child in t_rows.get_children():
		child.queue_free()
		
	for run in runs:
		var shortened_name := run.username as String
		if len(shortened_name) >= MAX_NAME_LENGTH:
			shortened_name = shortened_name.substr(0, MAX_NAME_LENGTH) + "..."

		_insert_table_row(run_position, shortened_name, run.time_ms, run.created_at, int(run.steam_id))
		run_position += 1

	if my_run != null:
		var pos := my_run.position
		if pos > 10:
			_insert_table_row(pos, my_run.username, my_run.time_ms, my_run.created_at, int(my_run.steam_id))
	
func _setup() -> void:
	map_name_label.text = "Map: " + Global.game_manager.current_map.name

	var medal_times: Array = Global.game_manager.current_map.medals[Global.game_manager.current_mode]
	for i in range(len(medal_time_labels)):
		medal_time_labels[i].text = str(medal_times[i]) + "s"

	await _load_runs()

	if Global.game_manager.admin:
		for child in admin_actions_container.get_children():
			child.queue_free()

		initialize_admin_actions()

func _insert_table_row(run_position: int, player_name: String, time: float, date: String, steam_id: int) -> void:
	var position_label := Label.new()
	t_rows.add_child(position_label)
	position_label.text = str(run_position) + "."
	position_label.custom_minimum_size.x = 30.0
	run_position += 1

	var name_label := ClickableLabel.new()
	t_rows.add_child(name_label)
	name_label.text = player_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var time_label := Label.new()
	t_rows.add_child(time_label)
	time_label.text = str(snapped(time / 1000, 0.001))
	time_label.size_flags_horizontal = Control.SIZE_EXPAND
	
	var date_label := Label.new()
	t_rows.add_child(date_label)
	date_label.text = str(date).substr(0, len("2024-10-10"))
	date_label.size_flags_horizontal = Control.SIZE_EXPAND
	
	var setup_race_btn_text := func() -> String:
		return "Race %s" % player_name if not player.map.currently_racing_steam_id == steam_id else "Stop Racing"
	
	const BUTTON_FONT_SIZES := 10
	var race_btn := Button.new()
	t_rows.add_child(race_btn)
	race_btn.text = setup_race_btn_text.call()
	race_btn.focus_mode = Control.FOCUS_NONE
	race_btn.size_flags_horizontal = Control.SIZE_EXPAND
	race_btn.set_meta("player_name", player_name)
	race_btn.custom_minimum_size.y = 1.0
	race_btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZES)
	
	race_btn.pressed.connect(
		func() -> void:
			if not player.map.currently_racing_steam_id == steam_id:
				var replay := await Global.server_bridge.get_replay(Global.game_manager.current_mode, Global.game_manager.current_map.name, steam_id)
				
				player.map.race_recording_bytes = Marshalls.base64_to_raw(replay)
				player.map.currently_racing_steam_id = steam_id
				
				var ghost_name_label: Label3D = player.map.recorder.ghost.get_node("Name")
				ghost_name_label.text = "%s's Ghost" % player_name
				
				for child in t_rows.get_children():
					if child.has_meta("player_name"):
						var b: Button = child
						var this_player_name: String = child.get_meta("player_name")
						b.text = "Race %s" % this_player_name
						
			else:
				player.map.race_recording_bytes.clear()
				player.map.currently_racing_steam_id = 0
				
				if player.map.recorder.ghost:
					player.map.recorder.ghost.visible = false
					
			race_btn.text = setup_race_btn_text.call()
	)
	
	var replay_btn := Button.new()
	
	t_rows.add_child(replay_btn)
	replay_btn.text = "View Replay"
	replay_btn.size_flags_horizontal = Control.SIZE_EXPAND
	replay_btn.focus_mode = Control.FOCUS_NONE
	replay_btn.pressed.connect(func() -> void:
		var replay := await Global.server_bridge.get_replay(Global.game_manager.current_mode, Global.game_manager.current_map.name, steam_id)
		if replay != "":
			Global.game_manager.replay_requested.emit(replay)
		else:
			Info.alert("Invalid replay request")
	)
	replay_btn.custom_minimum_size.y = 1.0
	replay_btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZES)
	
	name_label.pressed.connect(
		func() -> void:
			if not Global.game_manager.admin: return
			add_admin_actions_for_player(player_name, steam_id)
	)

func initialize_admin_actions() -> void:
	var maintenance := Global.game_manager.maintenance
	var toggle_maintenance_btn := Button.new()
	admin_actions_container.add_child(toggle_maintenance_btn)
	toggle_maintenance_btn.text = "Enable Game Maintenace" if not maintenance else "Disable Game Maintenance"
	toggle_maintenance_btn.focus_mode = Control.FOCUS_NONE
	
	toggle_maintenance_btn.pressed.connect(
		func() -> void:
			Info.alert("Toggled maintenance, please wait a few seconds to confirm.")
			Global.server_bridge.set_maintenance(not maintenance)
	)
	
func add_admin_actions_for_player(player_name: String, steam_id: int) -> void:
	for child in admin_actions_container.get_children():
		child.queue_free()
	
	initialize_admin_actions()
	
	var name_label := Label.new()
	admin_actions_container.add_child(name_label)
	name_label.text = "Actions for player: %s" % player_name
	
	var delete_btn := Button.new()
	admin_actions_container.add_child(delete_btn)
	delete_btn.text = "Delete Run"
	delete_btn.focus_mode = Control.FOCUS_NONE
	
	delete_btn.pressed.connect(
		func() -> void:
			for child in admin_actions_container.get_children():
				if child.has_meta("delete_btn"): return
				
			var confirm_btn := Button.new()
			delete_btn.add_sibling(confirm_btn)
			confirm_btn.set_meta("delete_btn", true)
			confirm_btn.text = "Are you sure?"
			confirm_btn.focus_mode = Control.FOCUS_NONE
			confirm_btn.pressed.connect(
				func() -> void:
					await Global.server_bridge.delete_run(Global.game_manager.current_mode, Global.game_manager.current_map.name, steam_id)
					confirm_btn.queue_free()
					)
	)
	
	var is_admin := await Global.server_bridge.is_admin(steam_id)
	var toggle_admin_btn := Button.new()
	admin_actions_container.add_child(toggle_admin_btn)
	toggle_admin_btn.text = "Give admin" if not is_admin else "Revoke admin"
	toggle_admin_btn.focus_mode = Control.FOCUS_NONE
	
	toggle_admin_btn.pressed.connect(
		func() -> void:
			Global.server_bridge.set_admin(steam_id, not is_admin)
	)
