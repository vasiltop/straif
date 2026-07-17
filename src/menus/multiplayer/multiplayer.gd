extends Control

@onready var refresh_servers_btn: Button = $M/P/M/V/Refresh
@onready var mode_tabs: TabBar = $M/P/M/V/ModeTabs
@onready var server_container: HFlowContainer = $M/P/M/V/ServerContainer
@onready var empty_state: Label = $M/P/M/V/EmptyState

const ServerButtonScene = preload("res://src/menus/multiplayer/server_button/server_button.tscn")
var cached_servers: Array[ServerBridge.ServerResponse] = []
var _refreshing := false

func _ready() -> void:
	mode_tabs.clear_tabs()
	mode_tabs.add_tab("All")
	mode_tabs.add_tab("Deathmatch")
	mode_tabs.add_tab("Elimination")
	refresh_servers_btn.pressed.connect(_refresh_servers)
	mode_tabs.tab_selected.connect(_on_mode_selected)
	_refresh_servers()

func _refresh_servers() -> void:
	if _refreshing:
		return

	_refreshing = true
	refresh_servers_btn.disabled = true
	cached_servers = await Global.server_bridge.get_servers()
	_refreshing = false
	refresh_servers_btn.disabled = false
	_render_servers()

func _on_mode_selected(_tab: int) -> void:
	_render_servers()

func _render_servers() -> void:
	var servers: Array[ServerBridge.ServerResponse] = []
	var mode := ""
	match mode_tabs.current_tab:
		1:
			mode = "deathmatch"
		2:
			mode = "elimination"

	for server: ServerBridge.ServerResponse in cached_servers:
		if mode.is_empty() or server.mode == mode:
			servers.append(server)

	for child in server_container.get_children():
		child.queue_free()

	for server in servers:
		var inst := ServerButtonScene.instantiate()
		server_container.add_child(inst)
		inst.set_info(server)

	empty_state.text = "No %s servers online." % mode if not mode.is_empty() else "No servers online."
	empty_state.visible = servers.is_empty()
