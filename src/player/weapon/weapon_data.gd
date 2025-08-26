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
@export var is_sniper: bool
@export var spread: float
@export var moving_spread: float
@export var bullet_count: float

func _init(
		name: String = "", 
		weapon_shot_delay: float = 1.0, 
		damage: float = 1.0, 
		scene: PackedScene = null, 
		shoot_sound: Resource = null, 
		recoil: float = 0.0, 
		attack_range := 5.0, 
		is_melee := false, 
		automatic := false,
		is_sniper := false,
		spread := 0.0,
		bullet_count := 1,
		moving_spread := 0.0
	) -> void:
	self.name = name
	self.weapon_shot_delay = weapon_shot_delay
	self.damage = damage
	self.scene = scene
	self.shoot_sound = shoot_sound
	self.recoil = recoil
	self.attack_range = attack_range
	self.is_melee = is_melee
	self.automatic = automatic
	self.is_sniper = is_sniper
	self.spread = spread
	self.bullet_count = bullet_count
	self.moving_spread = moving_spread
