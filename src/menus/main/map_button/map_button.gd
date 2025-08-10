class_name MapButton extends Panel

@onready var map_name_label: Label = $C/V/MapName
@onready var timer_label: Label = $C/V/Timer
@onready var play_btn: Button = $C/V/Play
@onready var medals: GridContainer = $C/V/Medals

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

func _ready() -> void:
	map = MapManager.get_map_with_name(map_name)
	map_name_label.text = map_name

	play_btn.pressed.connect(
		func() -> void:
			var base_path := "res://src/maps/"
			var path := base_path + map.name.to_lower().replace(" ", "_") + ".tscn"
			get_tree().change_scene_to_file(path)
			Lobby.current_map = map
	)
	
	for child: TextureRect in medals.get_children():
		child.texture = EMPTY_MEDAL

func set_personal_best(time: float, position: int, total: int) -> void:
	timer_label.text = "Not Completed"
	
	if time == -INF: return
	
	timer_label.text = "Personal Best: %.3f\nPosition: %d / %d" % [time, position, total]
	
	for i in range(MEDAL_COUNT):
		var medal: TextureRect = medals.get_child(i)
		if time <= map.medal_times[i]:
			earned_medals += 1
			medal.texture = index_to_medal[i]
