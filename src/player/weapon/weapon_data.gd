class_name WeaponData extends Resource

@export var name: String
@export var weapon_shot_delay: float
@export var damage: float
@export var scene: PackedScene
@export var shoot_sound: Resource
@export var recoil: float
@export var attack_range: float
@export var is_melee: bool
@export var automatic: bool

# include model, sounds, etc...

func _init(name: String = "", weapon_shot_delay: float = 1.0, damage: float = 1.0, scene: PackedScene = null, shoot_sound: Resource = null, recoil: float = 0.0, attack_range := 5.0, is_melee := false, automatic := false) -> void:
	self.name = name
	self.weapon_shot_delay = weapon_shot_delay
	self.damage = damage
	self.scene = scene
	self.shoot_sound = shoot_sound
	self.recoil = recoil
	self.attack_range = attack_range
	self.is_melee = is_melee
	self.automatic = false
