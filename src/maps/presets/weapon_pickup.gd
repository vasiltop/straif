class_name WeaponPickup extends Area3D

@onready var weapon_spawn: Node3D = $WeaponSpawn
@export var weapon: WeaponData

var weapon_scene: Node3D
var active := true

func _ready() -> void:
	var inst: Node3D = weapon.scene.instantiate()
	add_child(inst)
	inst.scale *= 0.5
	inst.global_position = weapon_spawn.global_position

	var gun_mesh: MeshInstance3D = inst.get_node("Mesh")
	gun_mesh.set_layer_mask_value(1, true)
	gun_mesh.set_layer_mask_value(2, false)

	weapon_scene = inst

func reset() -> void:
	weapon_scene.visible = true
	active = true

func _process(_delta: float) -> void:
	if not active: return

	var bodies := get_overlapping_bodies()

	for body in bodies:
		if body is Player:
			var p: Player = body
			if not p.is_me(): continue

			if Input.is_action_just_pressed("interact"):
				p.weapon_handler.set_weapon(weapon)
				weapon_scene.visible = false
				active = false

