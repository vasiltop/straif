class_name MapButton extends Panel

@onready var map_name_label: Label = $V/MapName
@onready var timer_label: Label = $V/Timer
@onready var play_btn: Button = $V/Play
@onready var medals: GridContainer = $V/Medals

const EMPTY_MEDAL = preload("res://src/textures/empty_medal.png")
const BRONZE_MEDAL = preload("res://src/textures/bronze_medal.png")
const SILVER_MEDAL = preload("res://src/textures/silver_medal.png")
const GOLD_MEDAL = preload("res://src/textures/gold_medal.png")
const AUTHOR_MEDAL = preload("res://src/textures/author_medal.png")

const PERSONAL_BEST_STRING := "Personal Best: "

var map_name: String

func _ready() -> void:
	var map := MapManager.get_map_with_name(map_name)

	play_btn.pressed.connect(
		func() -> void:
			var base_path := "res://src/maps/"
			var path := base_path + map.name.to_lower().replace(" ", "_") + ".tscn"
			get_tree().change_scene_to_file(path)
			Lobby.current_map = map
	)
	
	for child: TextureRect in medals.get_children():
		child.texture = EMPTY_MEDAL

func set_personal_best(time: float) -> void:
	timer_label.text = PERSONAL_BEST_STRING + str(snapped(time, 0.01))
