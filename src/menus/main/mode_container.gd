class_name ModeContainer extends Control

const MapButtonScene = preload("res://src/menus/main/map_button/map_button.tscn")

@export var mode: String
@onready var map_container: HFlowContainer = $Content/MapScroll/MapMargin/MapContainer

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
