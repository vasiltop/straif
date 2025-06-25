class_name WeaponData extends Resource

@export var name: String
@export var weapon_shot_delay: float
@export var damage: float
@export var scene: PackedScene
@export var shoot_sound: Resource

# include model, sounds, etc...

func _init(name: String = "", weapon_shot_delay: float = 1.0, damage: float = 1.0, scene: PackedScene = null, shoot_sound: Resource = null) -> void:
	self.name = name
	self.weapon_shot_delay = weapon_shot_delay
	self.damage = damage
	self.scene = scene
	self.shoot_sound = shoot_sound
