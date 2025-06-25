class_name WeaponHandler extends Node3D

const RAY_LENGTH := 1000

@onready var player: Player = $".."
var current_weapon: WeaponData = preload("res://src/player/weapon/rifle.tres") as WeaponData

func _process(_delta: float) -> void:
	if not player.is_me(): return

	if Input.is_action_just_pressed("attack"):
		_try_shoot()

func _try_shoot() -> void:
	if current_weapon == null: return
	if not player.map or not player.map.running: return

	var space_state := get_world_3d().direct_space_state
	var cam := player.camera
	var mouse_pos := get_viewport().get_mouse_position()

	var origin := cam.project_ray_origin(mouse_pos)
	var end := origin + cam.project_ray_normal(mouse_pos) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	var result := space_state.intersect_ray(query)
	
	if not result.has("collider"): return

	var collider: Object = result.collider

	if collider is BodyPart:
		var body_part: BodyPart = collider
		body_part.apply_damage(current_weapon.damage)
