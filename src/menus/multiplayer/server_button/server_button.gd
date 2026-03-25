class_name ServerButton extends Panel

@onready var name_label: Label = $M/C/P/M/V/Name
@onready var mode_label: Label = $M/C/P/M/V/Mode
@onready var map_label: Label = $M/C/P/M/V/Map
@onready var player_count_label: Label = $M/C/P/M/V/PlayerCount
@onready var join_btn: Button = $M/C/V/Join

var info: ServerBridge.ServerResponse

func _ready() -> void:
	join_btn.pressed.connect(
		func() -> void:
			Global.game_manager.connect_to_server(info.ip, info.port)
			Global.game_manager.current_pvp_map = info.map
			Global.game_manager.current_pvp_mode = info.mode
	)

func set_info(info: ServerBridge.ServerResponse) -> void:
	self.info = info
	name_label.text = info.name
	mode_label.text = "Mode: %s" % info.mode
	map_label.text = "Map: %s" % info.map
	player_count_label.text = "Players: %d / %d" % [info.player_count, info.max_players]
	
	var sb := StyleBoxTexture.new()
	sb.texture = Global.map_manager.get_map_image(info.map)
	add_theme_stylebox_override("panel", sb)
