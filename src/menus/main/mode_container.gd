class_name ModeContainer extends Control

const MapButtonScene = preload("res://src/menus/main/map_button/map_button.tscn")

@export var mode: String
var map_container := HFlowContainer.new()

func _ready() -> void:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND
	sc.set_anchors_preset(PRESET_FULL_RECT)
	add_child(sc)
	var margin_container := MarginContainer.new()
	var margin := 20
	margin_container.add_theme_constant_override("margin_left", margin)
	margin_container.add_theme_constant_override("margin_top", margin)
	margin_container.add_theme_constant_override("margin_right", margin)
	margin_container.add_theme_constant_override("margin_bottom", margin)
	sc.add_child(margin_container)
	margin_container.add_child(map_container)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_container.theme
	map_container.add_theme_constant_override("h_separation", 15)
	map_container.add_theme_constant_override("v_separation", 15)

func add_map(map: MapData, mode: String, pb: float, position: int, total: int) -> void:
	var btn: MapButton = MapButtonScene.instantiate()
	btn.map_name = map.name
	btn.mode = mode
	map_container.add_child(btn)
	btn.set_personal_best(pb, position, total, mode)

func get_map(name: String) -> MapButton:
	for child: MapButton in map_container.get_children():
		if child.map_name == name:
			return child
	
	return null
