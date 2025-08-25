class_name MainMenu extends Control

@onready var avatar: TextureRect = $MarginContainer/Content/Header/Left/Avatar
@onready var username_label: Label = $MarginContainer/Content/Header/Left/Label
@onready var quit_btn: Button = $MarginContainer/Content/Header/Right/Quit
@onready var create_lobby_btn: Button = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/CreateLobby/Form/Create
@onready var lobby_name_input: LineEdit = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/CreateLobby/Form/Name/Name
@onready var lobby_type_input: OptionButton = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/CreateLobby/Form/Type/Type
@onready var max_members_input: SpinBox = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/CreateLobby/Form/MaxMembers/MaxMembers
@onready var my_lobby_control: Control = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/MyLobby
@onready var create_lobby_control: Control = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/CreateLobby
@onready var refresh_lobby_search_btn: Button = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/Lobbies/Title/Refresh
@onready var lobby_list_container: HFlowContainer = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/Lobbies/ScrollContainer/Container
@onready var leave_lobby_btn: Button = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/MyLobby/Title/Button
@onready var my_lobby_members_container: VBoxContainer = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/MyLobby/Players
@onready var map_container: VBoxContainer = $MarginContainer/Content/Body/Play/M/V/S/Maps
@onready var host_local_btn: Button = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/CreateLobby/Form/HostLocal
@onready var join_local_btn: Button = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/Lobbies/Title/JoinLocal
@onready var _lobby_refresh_timer := BetterTimer.new(self, 1.0, _on_refresh_lobby_search)
@onready var save_settings_btn: Button = $MarginContainer/Content/Body/Settings/Save
@onready var version_error: Control = $MarginContainer/VersionError
@onready var discord_btn: TextureButton = $MarginContainer/Content/Header/Right/Discord
@onready var medals_earned_label: Label = $MarginContainer/Content/Body/Play/M/V/H/MedalsEarned
@onready var mode_switcher: TabContainer = $MarginContainer/Content/Body/Play/M/V/ModeSwitcher

const MapButtonScene = preload("res://src/menus/main/map_button/map_button.tscn")

func _ready() -> void:
	_instantiate_maps()
	Steam.avatar_loaded.connect(_on_loaded_avatar)
	quit_btn.pressed.connect(get_tree().quit)
	#create_lobby_btn.pressed.connect(_on_create_lobby)
	#refresh_lobby_search_btn.pressed.connect(_on_refresh_lobby_search)
	#Steam.lobby_match_list.connect(_on_lobby_match_list)
	Global.game_manager.my_lobby_changed.connect(_on_my_lobby_changed)
	#leave_lobby_btn.pressed.connect(Global.game_manager.leave)
	#host_local_btn.pressed.connect(Global.game_manager.create_enet_lobby)
	#join_local_btn.pressed.connect(Global.game_manager.join_enet_lobby)
	save_settings_btn.pressed.connect(Global.settings_manager.save)
	Global.server_bridge.invalid_version.connect(func() -> void: version_error.visible = true)
	
	Steam.getPlayerAvatar()
	username_label.text = Steam.getPersonaName()

	#my_lobby_control.visible = false
	#create_lobby_control.visible = true

	_lobby_refresh_timer.start()
		
	if Global.game_manager.lobby_id != 0 && Global.game_manager.network_type == Global.game_manager.NETWORK_TYPE.STEAM:
		Global.game_manager.update_lobby_members()
	
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

func _on_my_lobby_changed() -> void:
	_on_refresh_lobby_search()
	my_lobby_control.visible = Global.game_manager.lobby_id != 0
	create_lobby_control.visible = Global.game_manager.lobby_id == 0

	for child in my_lobby_members_container.get_children():
		child.queue_free()

	for member in Global.game_manager.lobby_members:
		var name_label := Label.new()
		var map_status := "Main Menu"

		if member.current_map_id != -1:
			map_status = Global.map_manager.get_map_with_id(member.current_map_id).name

		name_label.text = member.name + " - In " + map_status
		my_lobby_members_container.add_child(name_label)

func _on_lobby_match_list(lobbies: Array) -> void:
	#for child in lobby_list_container.get_children():
	#	child.queue_free()

	for lobby_id: int in lobbies:
		var lobby_name := Steam.getLobbyData(lobby_id, "name")
		if lobby_name == "": continue #lobby_name = "Unnamed Lobby"
		if len(lobby_name) >= 32: lobby_name = lobby_name.substr(0, 32)

		var btn := Button.new()
		btn.text = lobby_name
		btn.custom_minimum_size = Vector2(100, 100)

		lobby_list_container.add_child(btn)
		btn.pressed.connect(
			func() -> void:
				if lobby_id != Global.game_manager.lobby_id:
					Global.game_manager.join_steam_lobby(lobby_id)
		)

func _on_refresh_lobby_search() -> void:
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()

func _on_loaded_avatar(_user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	var image := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)

	if avatar_size > 128:
		image.resize(128, 128, Image.INTERPOLATE_LANCZOS)

	avatar.set_texture(ImageTexture.create_from_image(image))

func _on_create_lobby() -> void:
	if Global.game_manager.lobby_id != 0: return

	var selected_lobby_type := lobby_type_input.get_selected_id()
	var lobby_type: SteamMultiplayerPeer.LobbyType
	match selected_lobby_type:
		0: lobby_type = SteamMultiplayerPeer.LobbyType.LOBBY_TYPE_PRIVATE
		1: lobby_type = SteamMultiplayerPeer.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
		2: lobby_type = SteamMultiplayerPeer.LobbyType.LOBBY_TYPE_PUBLIC
		3: lobby_type = SteamMultiplayerPeer.LobbyType.LOBBY_TYPE_INVISIBLE

	var max_members := int(max_members_input.get_line_edit().text)
	Global.game_manager.create_steam_lobby(lobby_type, max_members)
	Global.game_manager.set_lobby_name(lobby_name_input.text)
