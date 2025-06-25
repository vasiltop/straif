class_name WeaponData extends Resource

@export var name: String
@export var weapon_shot_delay: float
@export var damage: float
@export var scene: PackedScene

# include model, sounds, etc...

func _init(name: String = "", weapon_shot_delay: float = 1.0, damage: float = 1.0, scene: PackedScene = null) -> void:
	self.name = name
	self.weapon_shot_delay = weapon_shot_delay
	self.damage = damage
	self.scene = scene
