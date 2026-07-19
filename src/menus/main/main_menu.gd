class_name MainMenu extends Control

@onready var avatar: TextureRect = $Center/Shell/Pad/HBox/Sidebar/Identity/Avatar
@onready var username_label: Label = $Center/Shell/Pad/HBox/Sidebar/Identity/Label
@onready var quit_btn: Button = $Center/Shell/Pad/HBox/Sidebar/Quit
@onready var discord_btn: Button = $Center/Shell/Pad/HBox/Sidebar/Discord
@onready var nav: VBoxContainer = $Center/Shell/Pad/HBox/Sidebar/Nav
@onready var body: TabContainer = $Center/Shell/Pad/HBox/Body
@onready var mode_select: HBoxContainer = $Center/Shell/Pad/HBox/Body/Play/M/V/ModeSelect
@onready var mode_stack: Control = $Center/Shell/Pad/HBox/Body/Play/M/V/ModeStack

const MODES := [["target", "Target Practice"], ["bhop", "Movement Only"]]
var mode_to_container: Dictionary[String, ModeContainer] = { }

func _ready() -> void:
	Global.multiplayer.multiplayer_peer = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_instantiate_maps()
	_build_mode_select()
	quit_btn.pressed.connect(get_tree().quit)

	if Global.steam_available():
		Steam.avatar_loaded.connect(_on_loaded_avatar)
		Steam.getPlayerAvatar()
	username_label.text = Global.display_name()

	discord_btn.pressed.connect(func() -> void: OS.shell_open(Global.server_bridge.DISCORD_URL))

	var nav_buttons := nav.get_children()
	for i in nav_buttons.size():
		var idx := i
		nav_buttons[idx].pressed.connect(func() -> void: body.current_tab = idx)

func _instantiate_maps() -> void:
	for child in mode_stack.get_children():
		if child is not ModeContainer:
			continue
		var mode_container := child as ModeContainer
		mode_to_container[mode_container.mode] = mode_container

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

func _build_mode_select() -> void:
	var current := Global.game_manager.current_mode
	var group := ButtonGroup.new()
	for entry in MODES:
		var btn := Button.new()
		btn.text = entry[1]
		btn.toggle_mode = true
		btn.button_group = group
		btn.theme_type_variation = &"Segment"
		btn.focus_mode = Control.FOCUS_NONE
		btn.button_pressed = entry[0] == current
		btn.pressed.connect(_select_mode.bind(entry[0]))
		mode_select.add_child(btn)
	_select_mode(current)

func _select_mode(mode: String) -> void:
	Global.game_manager.current_mode = mode
	for m in mode_to_container:
		mode_to_container[m].visible = m == mode

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
