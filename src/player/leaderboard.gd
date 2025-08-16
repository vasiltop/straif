class_name Leaderboard extends Panel

@onready var t_rows: GridContainer = $M/V/TRows
@onready var map_name_label: Label = $M/V/MapName
@onready var dec_page_btn: Button = $"M/V/H/<"
@onready var inc_page_btn: Button = $"M/V/H/>"
@onready var page_label: Label = $M/V/H/Page
@onready var middle: HBoxContainer = $".."
@onready var player: Player = $"../../.."

@onready var medal_time_labels: Array[Label] = [
	$M/V/MedalInfo/BronzeTime,
	$M/V/MedalInfo/SilverTime,
	$M/V/MedalInfo/GoldTime,
	$M/V/MedalInfo/PlatTime,
	$M/V/MedalInfo/AuthorTime
]

const PAGE_SIZE := 10
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

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("leaderboard"):
		middle.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_setup()
	elif Input.is_action_just_released("leaderboard"):
		middle.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _load_runs() -> void:
	for child in t_rows.get_children():
		child.queue_free()
		
	var run_result := await Http.get_runs(Lobby.current_map.name, current_page)
	total_pages = max(1, ceil(run_result.count as float / PAGE_SIZE))
	page_label.text = "Page %d of %d" % [current_page, total_pages]
	
	var runs: Array = run_result.data
	var run_position := (current_page - 1) * PAGE_SIZE + 1
	for run: Dictionary in runs:
		var shortened_name := run.username as String
		if len(shortened_name) >= MAX_NAME_LENGTH:
			shortened_name = shortened_name.substr(0, MAX_NAME_LENGTH) + "..."
			
		_insert_table_row(run_position, shortened_name, run.time_ms as float, run.created_at as String, run.steam_id as int)
		run_position += 1

func _setup() -> void:
	map_name_label.text = "Map: " + Lobby.current_map.name
	
	for i in range(len(medal_time_labels)):
		medal_time_labels[i].text = str(Lobby.current_map.medal_times[i]) + "s"
	
	_load_runs()
		
	var my_run := await Http.get_my_run(Lobby.current_map.name)
	
	if my_run != {}:
		var pos := my_run.position as int
		if pos > 10:
			_insert_table_row(pos, my_run.username as String, my_run.time_ms as float, my_run.created_at as String, my_run.steam_id as int)

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

	if Lobby.admin:
		name_label.pressed.connect(func() -> void:
			var replay := await Http.get_replay(Lobby.current_map.name, steam_id)
			if replay != "":
				Lobby.replay_requested.emit(replay)
			else:
				Info.alert("Invalid replay request")
		)
	
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
		
	var race_btn := Button.new()
	t_rows.add_child(race_btn)
	race_btn.text = setup_race_btn_text.call()
	race_btn.focus_mode = Control.FOCUS_NONE
	race_btn.size_flags_horizontal = Control.SIZE_EXPAND
	
	race_btn.pressed.connect(
		func() -> void:
			if not player.map.currently_racing_steam_id == steam_id:
				var replay := await Http.get_replay(Lobby.current_map.name, steam_id)
				player.map.race_recording_bytes = Marshalls.base64_to_raw(replay)
				player.map.currently_racing_steam_id = steam_id
				var ghost_name_label: Label3D = player.map.recorder.ghost.get_node("Name")
				ghost_name_label.text = "%s's Ghost" % player_name
			else:
				player.map.race_recording_bytes.clear()
				player.map.currently_racing_steam_id = 0
				
				if player.map.recorder.ghost:
					player.map.recorder.ghost.visible = false
				
			race_btn.text = setup_race_btn_text.call()
	)
