extends CSGCombiner3D

@onready var zone: Area3D = $".."

var ZoneMaterial: StandardMaterial3D = preload("res://src/maps/presets/zone.tres").duplicate()

func _ready() -> void:
	var sm: StandardMaterial3D = ZoneMaterial
	
	match zone.name:
		"EndZone": sm.albedo_color = Color("ff000004")
		"StartZone": sm.albedo_color = Color("00ff0004")
	
	material_override = sm
