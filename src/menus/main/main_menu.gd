class_name MainMenu extends Control

@export var target_practice_leaderboard: VBoxContainer
@export var movement_only_leaderboard: VBoxContainer

@onready var avatar: TextureRect = $MarginContainer/Content/Header/Left/Avatar
@onready var username_label: Label = $MarginContainer/Content/Header/Left/Label
@onready var quit_btn: Button = $MarginContainer/Content/Header/Right/Quit
@onready var discord_btn: TextureButton = $MarginContainer/Content/Header/Right/Discord
@onready var mode_switcher: TabContainer = $MarginContainer/Content/Body/Speedrun/M/V/ModeSwitcher
@onready var leaderboard_timer := BetterTimer.new(Global, 3.0, _on_leaderboard_timer)

const MapButtonScene = preload("res://src/menus/main/map_button/map_button.tscn")


func _on_leaderboard_timer() -> void:
	var target_lb := await Global.server_bridge.get_overall_leaderboard("target")

	for child in target_practice_leaderboard.get_children():
		child.queue_free()

	var label_from_run = func(run, pos) -> Label:
		var label := Label.new()
		label.text = "%s | %s - %s" % [pos, run.username, run.points]
		return label

	var lb_pos := 1
	for run in target_lb:
		target_practice_leaderboard.add_child(label_from_run.call(run, lb_pos))
		lb_pos += 1

	var bhop_lb := await Global.server_bridge.get_overall_leaderboard("bhop")

	for child in movement_only_leaderboard.get_children():
		child.queue_free()

	lb_pos = 1
	for run in bhop_lb:
		movement_only_leaderboard.add_child(label_from_run.call(run, lb_pos))
		lb_pos += 1


func _ready() -> void:
	Global.multiplayer.multiplayer_peer = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_instantiate_maps()
	quit_btn.pressed.connect(get_tree().quit)

	if Global.steam_available():
		Steam.avatar_loaded.connect(_on_loaded_avatar)
		Steam.getPlayerAvatar()
	username_label.text = Global.display_name()

	discord_btn.pressed.connect(func() -> void: OS.shell_open(Global.server_bridge.DISCORD_URL))

	leaderboard_timer.start()


func _instantiate_maps() -> void:
	var mode_to_container: Dictionary[String, ModeContainer]

	for child: ModeContainer in mode_switcher.get_children():
		mode_to_container[child.mode] = child

	mode_to_container[Global.game_manager.current_mode].visible = true

	for map in Global.map_manager.maps:
		for mode: String in map.modes:
			var container := mode_to_container[mode]
			var pb_info := Global.game_manager.map_name_to_pb_info.get(map.name, null)

			if pb_info == null:
				container.add_map(map, mode, INF, 0, 0)
			else:
				var mode_info: Dictionary = pb_info.mode_to_map_info[mode]
				container.add_map(map, mode, mode_info.pb as float, mode_info.position as int, mode_info.total as int)

	for mode in mode_to_container:
		var response := await Global.server_bridge.get_my_runs(mode)
		if response == null:
			return

		for run in response.runs:
			var btn := mode_to_container[mode].get_map(run.map_name)
			if btn == null:
				continue
			btn.set_personal_best(snapped(float(run.time_ms) / 1000, 0.001) as float, run.position, run.total, mode)


func _on_refresh_lobby_search() -> void:
	if not Global.steam_available():
		return
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()


func _on_loaded_avatar(_user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	var image := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)

	if avatar_size > 128:
		image.resize(128, 128, Image.INTERPOLATE_LANCZOS)

	avatar.set_texture(ImageTexture.create_from_image(image))
