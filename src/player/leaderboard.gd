class_name Leaderboard extends Panel

@onready var t_rows: GridContainer = $M/V/TRows
@onready var map_name_label: Label = $M/V/MapName
@onready var bronze_time_label: Label = $M/V/MedalInfo/BronzeTime
@onready var silver_time_label: Label = $M/V/MedalInfo/SilverTime
@onready var gold_time_label: Label = $M/V/MedalInfo/GoldTime
@onready var author_time_label: Label = $M/V/MedalInfo/AuthorTime

func _ready() -> void:
	visible = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("leaderboard"):
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_setup()
	elif Input.is_action_just_released("leaderboard"):
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup() -> void:
	map_name_label.text = "Map: " + Lobby.current_map.name
	bronze_time_label.text = str(Lobby.current_map.medal_times[0]) + "s"
	silver_time_label.text = str(Lobby.current_map.medal_times[1]) + "s"
	gold_time_label.text = str(Lobby.current_map.medal_times[2]) + "s"
	author_time_label.text = str(Lobby.current_map.medal_times[3]) + "s"
	
	for child in t_rows.get_children():
		child.queue_free()
	
	var runs: Array = await Http.get_runs(Lobby.current_map.name, 0)
	var run_position := 1
	
	for run: Dictionary in runs:
		_insert_table_row(run_position, run.username as String, run.time_ms as float, run.created_at as String, run.steam_id as int)
		run_position += 1
		
	var my_run := await Http.get_my_run(Lobby.current_map.name)
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
