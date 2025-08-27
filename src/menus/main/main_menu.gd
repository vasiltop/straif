class_name MainMenu extends Control

@onready var avatar: TextureRect = $MarginContainer/Content/Header/Left/Avatar
@onready var username_label: Label = $MarginContainer/Content/Header/Left/Label
@onready var quit_btn: Button = $MarginContainer/Content/Header/Right/Quit
@onready var save_settings_btn: Button = $MarginContainer/Content/Body/Settings/Save
@onready var discord_btn: TextureButton = $MarginContainer/Content/Header/Right/Discord
@onready var mode_switcher: TabContainer = $MarginContainer/Content/Body/Play/M/V/ModeSwitcher

const MapButtonScene = preload("res://src/menus/main/map_button/map_button.tscn")

func _ready() -> void:
	_instantiate_maps()
	Steam.avatar_loaded.connect(_on_loaded_avatar)
	quit_btn.pressed.connect(get_tree().quit)
	save_settings_btn.pressed.connect(Global.settings_manager.save)
	
	Steam.getPlayerAvatar()
	username_label.text = Steam.getPersonaName()
	
	discord_btn.pressed.connect(
		func() -> void:
			OS.shell_open(Global.server_bridge.DISCORD_URL)
	)

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
			if btn == null: continue
			btn.set_personal_best(snapped(float(run.time_ms) / 1000, 0.001) as float, run.position, run.total, mode)

func _on_refresh_lobby_search() -> void:
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()

func _on_loaded_avatar(_user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	var image := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)

	if avatar_size > 128:
		image.resize(128, 128, Image.INTERPOLATE_LANCZOS)

	avatar.set_texture(ImageTexture.create_from_image(image))
