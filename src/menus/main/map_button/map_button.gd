class_name MapButton extends Panel

@onready var map_image: TextureRect = $MapImage
@onready var map_name_label: Label = $Layout/Info/M/V/MapName
@onready var timer_label: Label = $Layout/Info/M/V/Timer
@onready var medals: GridContainer = $Layout/Info/M/V/Medals

const EMPTY_MEDAL = preload("res://src/textures/empty_medal.png")
const BRONZE_MEDAL = preload("res://src/textures/bronze_medal.png")
const SILVER_MEDAL = preload("res://src/textures/silver_medal.png")
const GOLD_MEDAL = preload("res://src/textures/gold_medal.png")
const PLAT_MEDAL = preload("res://src/textures/plat_medal.png")
const AUTHOR_MEDAL = preload("res://src/textures/author_medal.png")

const PERSONAL_BEST_STRING := "Personal Best: "
const MEDAL_COUNT := 5

var map_name: String
var initialized_personal_best: bool
var map: MapData
var index_to_medal: Array[Texture] = [BRONZE_MEDAL, SILVER_MEDAL, GOLD_MEDAL, PLAT_MEDAL, AUTHOR_MEDAL]
var earned_medals := 0
var mode: String

func _ready() -> void:
	_apply_card_style(false)
	mouse_entered.connect(_apply_card_style.bind(true))
	mouse_exited.connect(_apply_card_style.bind(false))

	map = Global.map_manager.get_map_with_name(map_name)
	map_name_label.text = map_name
	map_image.texture = map.image

	for child: TextureRect in medals.get_children():
		child.texture = EMPTY_MEDAL

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var base_path := "res://src/maps/speedrun/"
		var path := base_path + map.name.to_lower().replace(" ", "_") + ".tscn"
		get_tree().change_scene_to_file(path)
		Global.game_manager.current_map = map
		Global.game_manager.current_mode = mode

func set_personal_best(time: float, position: int, total: int, mode: String) -> void:
	timer_label.text = "PB: --\nRANK: -- / --"

	var info := Global.game_manager.map_name_to_pb_info.get(map_name)
	if info == null:
		Global.game_manager.map_name_to_pb_info[map_name] = Global.game_manager.PbInfo.new()

	var dict := Global.game_manager.map_name_to_pb_info[map_name].mode_to_map_info[mode]
	dict.position = position
	dict.total = total
	dict.pb = time

	if time == INF:
		return
	timer_label.text = "PB: %.3fs\nRANK: %d / %d" % [time, position, total]

	var medal_times: Array = Global.map_manager.get_map_with_name(map_name).medals[mode]
	for i in range(MEDAL_COUNT):
		var medal: TextureRect = medals.get_child(i)
		if time <= medal_times[i]:
			earned_medals += 1
			medal.texture = index_to_medal[i]

func _apply_card_style(hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.HOVER_FILL if hovered else Color(0, 0, 0, 0)
	style.border_color = Palette.TEXT if hovered else Palette.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", style)
