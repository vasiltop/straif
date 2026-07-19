extends Control

@onready var refresh_servers_btn: Button = $M/P/M/V/Toolbar/Refresh
@onready var mode_tabs: HBoxContainer = $M/P/M/V/Toolbar/ModeTabs
@onready var server_container: HFlowContainer = $M/P/M/V/Scroll/ServerContainer
@onready var empty_state: Label = $M/P/M/V/EmptyState

const ServerButtonScene = preload("res://src/menus/multiplayer/server_button/server_button.tscn")
const FILTERS := ["All", "Deathmatch", "Elimination"]
var cached_servers: Array[ServerBridge.ServerResponse] = []
var current_filter := 0
var _refreshing := false

func _ready() -> void:
	var group := ButtonGroup.new()
	for i in FILTERS.size():
		var btn := Button.new()
		btn.text = FILTERS[i]
		btn.toggle_mode = true
		btn.button_group = group
		btn.theme_type_variation = &"Segment"
		btn.focus_mode = Control.FOCUS_NONE
		btn.button_pressed = i == 0
		btn.pressed.connect(_on_mode_selected.bind(i))
		mode_tabs.add_child(btn)
	refresh_servers_btn.pressed.connect(_refresh_servers)
	server_container.resized.connect(_fit)
	_refresh_servers()

func _fit() -> void:
	CardGrid.fit(server_container, 3)

func _refresh_servers() -> void:
	if _refreshing:
		return

	_refreshing = true
	refresh_servers_btn.disabled = true
	cached_servers = await Global.server_bridge.get_servers()
	_refreshing = false
	refresh_servers_btn.disabled = false
	_render_servers()

func _on_mode_selected(tab: int) -> void:
	current_filter = tab
	_render_servers()

func _render_servers() -> void:
	var servers: Array[ServerBridge.ServerResponse] = []
	var mode := ""
	match current_filter:
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
	_fit.call_deferred()

	empty_state.text = "No %s servers online." % mode if not mode.is_empty() else "No servers online."
	empty_state.visible = servers.is_empty()
