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
@onready var map_container: VBoxContainer = $MarginContainer/Content/Body/Play/MarginContainer/ScrollContainer/Maps
@onready var host_local_btn: Button = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/CreateLobby/Form/HostLocal
@onready var join_local_btn: Button = $MarginContainer/Content/Body/Lobby/MarginContainer/LobbySplit/Lobbies/Title/JoinLocal
@onready var _lobby_refresh_timer := BetterTimer.new(self, 1.0, _on_refresh_lobby_search)
@onready var save_settings_btn: Button = $MarginContainer/Content/Body/Settings/Save
@onready var version_error: Control = $MarginContainer/VersionError
@onready var discord_btn: TextureButton = $MarginContainer/Content/Header/Right/Discord

const MapButtonScene = preload("res://src/menus/main/map_button/map_button.tscn")

func _ready() -> void:
	_instantiate_maps()
	Steam.avatar_loaded.connect(_on_loaded_avatar)
	quit_btn.pressed.connect(get_tree().quit)
	create_lobby_btn.pressed.connect(_on_create_lobby)
	refresh_lobby_search_btn.pressed.connect(_on_refresh_lobby_search)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Lobby.my_lobby_changed.connect(_on_my_lobby_changed)
	leave_lobby_btn.pressed.connect(Lobby.leave)
	host_local_btn.pressed.connect(Lobby.create_enet_lobby)
	join_local_btn.pressed.connect(Lobby.join_enet_lobby)
	save_settings_btn.pressed.connect(Settings.save)
	Http.invalid_version.connect(func() -> void: version_error.visible = true)

	Steam.getPlayerAvatar()
	username_label.text = Steam.getPersonaName()

	my_lobby_control.visible = false
	create_lobby_control.visible = true

	_lobby_refresh_timer.start()
		
	if Lobby.lobby_id != 0 && Lobby.network_type == Lobby.NETWORK_TYPE.STEAM:
		Lobby.update_lobby_members()
	
	discord_btn.pressed.connect(
		func() -> void:
			OS.shell_open(Http.DISCORD_URL)
	)

func _instantiate_maps() -> void:
	var tiers := 3
	var tier_labels := {}
	var tier_to_container := {}
	var labels := ["Easy", "Intermediate", "Hard"]

	for tier in tiers:
		var label := Label.new()
		map_container.add_child(label)
		label.text = "%s: " % labels[tier] 
		tier_labels[tier] = label

		var container := HFlowContainer.new()
		map_container.add_child(container)
		tier_to_container[tier] = container

	var mm: Maps = MapManager

	for map in mm.maps:
		Lobby.map_name_to_time[map.name] = INF

		var btn: MapButton = MapButtonScene.instantiate()
		btn.map_name = map.name
		(tier_to_container[map.tier] as Control).add_child(btn)

	var runs := await Http.get_my_runs()
	for run: Dictionary in runs:
		for tier: int in tier_to_container:
			var container: HFlowContainer = tier_to_container[tier]
			for map_button: MapButton in container.get_children():
				if map_button.map_name != run.map_name: continue
				var time: float = run.time_ms / 1000
				Lobby.map_name_to_time[run.map_name] = time
				map_button.set_personal_best(time)
				map_button.initialized_personal_best = true
				
	for tier: int in tier_to_container:
		var container: HFlowContainer = tier_to_container[tier]
		for map_button: MapButton in container.get_children():
			if not map_button.initialized_personal_best:
				map_button.set_personal_best(-INF)

	for tier: int in tier_to_container:
		var container: Control = tier_to_container[tier]
		var label: Label = tier_labels[tier]

		if container.get_child_count() == 0:
			label.queue_free()
			container.queue_free()

func _on_my_lobby_changed() -> void:
	_on_refresh_lobby_search()
	my_lobby_control.visible = Lobby.lobby_id != 0
	create_lobby_control.visible = Lobby.lobby_id == 0

	for child in my_lobby_members_container.get_children():
		child.queue_free()

	for member in Lobby.lobby_members:
		var name_label := Label.new()
		var map_status := "Main Menu"

		if member.current_map_id != -1:
			map_status = MapManager.get_map_with_id(member.current_map_id).name

		name_label.text = member.name + " - In " + map_status
		my_lobby_members_container.add_child(name_label)

func _on_lobby_match_list(lobbies: Array) -> void:
	for child in lobby_list_container.get_children():
		child.queue_free()

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
				if lobby_id != Lobby.lobby_id:
					Lobby.join_steam_lobby(lobby_id)
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
	if Lobby.lobby_id != 0: return

	var selected_lobby_type := lobby_type_input.get_selected_id()
	var lobby_type: SteamMultiplayerPeer.LobbyType
	match selected_lobby_type:
		0: lobby_type = SteamMultiplayerPeer.LobbyType.LOBBY_TYPE_PRIVATE
		1: lobby_type = SteamMultiplayerPeer.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
		2: lobby_type = SteamMultiplayerPeer.LobbyType.LOBBY_TYPE_PUBLIC
		3: lobby_type = SteamMultiplayerPeer.LobbyType.LOBBY_TYPE_INVISIBLE

	var max_members := int(max_members_input.get_line_edit().text)
	Lobby.create_steam_lobby(lobby_type, max_members)
	Lobby.set_lobby_name(lobby_name_input.text)
