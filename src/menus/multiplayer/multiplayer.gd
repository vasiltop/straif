extends Control

@onready var refresh_servers_btn: Button = $M/P/M/V/Refresh
@onready var server_container: HFlowContainer = $M/P/M/V/ServerContainer

const ServerButtonScene = preload("res://src/menus/multiplayer/server_button/server_button.tscn")

func _ready() -> void:
	refresh_servers_btn.pressed.connect(_refresh_servers)
	_refresh_servers()
	
func _refresh_servers() -> void:
	var servers := await Global.server_bridge.get_servers()
	
	for child in server_container.get_children():
		child.queue_free()
	
	for server in servers:
		var inst := ServerButtonScene.instantiate()
		server_container.add_child(inst)
		inst.set_info(server)
