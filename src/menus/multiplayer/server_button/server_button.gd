class_name ServerButton extends Panel

@onready var map_image: TextureRect = $MapImage
@onready var name_label: Label = $Layout/Info/M/V/Name
@onready var meta_label: Label = $Layout/Info/M/V/Meta
@onready var player_count_label: Label = $Layout/Info/M/V/PlayerCount

var info: ServerBridge.ServerResponse

func _ready() -> void:
	_apply_card_style(false)
	mouse_entered.connect(_apply_card_style.bind(true))
	mouse_exited.connect(_apply_card_style.bind(false))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Global.game_manager.connect_to_server(info.ip, info.port)
		Global.game_manager.current_pvp_map = info.map
		Global.game_manager.current_pvp_mode = info.mode

func set_info(info: ServerBridge.ServerResponse) -> void:
	self.info = info
	name_label.text = info.name
	meta_label.text = "%s · %s" % [info.mode.to_upper(), info.map]
	player_count_label.text = "PLAYERS: %d / %d" % [info.player_count, info.max_players]
	map_image.texture = Global.map_manager.get_map_image(info.map)

func _apply_card_style(hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.HOVER_FILL if hovered else Color(0, 0, 0, 0)
	style.border_color = Palette.TEXT if hovered else Palette.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", style)
