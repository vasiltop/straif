class_name WeaponPickup extends Area3D

@onready var player: Player = $"../../Player"
@onready var weapon_spawn: Node3D = $WeaponSpawn
@export var weapon: WeaponData

const EquipSound = preload("res://src/sounds/equip.mp3")

var audio_player := AudioStreamPlayer.new()
var weapon_scene: Node3D
var active := true
var is_touching_player := false

func _ready() -> void:
	var inst: Node3D = weapon.scene.instantiate()
	add_child(inst)
	add_child(audio_player)
	inst.scale *= 0.5
	inst.global_position = weapon_spawn.global_position

	var gun_mesh: MeshInstance3D = inst.get_node("Mesh")
	gun_mesh.set_layer_mask_value(1, true)
	gun_mesh.set_layer_mask_value(2, false)

	weapon_scene = inst
	
	body_entered.connect(
		func(body: Node3D) -> void:
			if body is Player:
				var p := body as Player
				if p.is_me():
					is_touching_player = true
	)
	
	body_exited.connect(
		func(body: Node3D) -> void:
			if body is Player:
				var p := body as Player
				if p.is_me():
					is_touching_player = false
	)

func reset() -> void:
	weapon_scene.visible = true
	active = true
	is_touching_player = false

func _process(delta: float) -> void:
	if not active: return
	
	weapon_scene.rotate_y(deg_to_rad(45 * delta))
	weapon_scene.global_position.y = weapon_spawn.global_position.y + sin(float(Time.get_ticks_msec()) / 1000) / 7
	
	if player.map.running and is_touching_player and (player.weapon_handler.current_weapon == null or Input.is_action_just_pressed("interact")):
		player.weapon_handler.set_weapon(weapon)
		weapon_scene.visible = false
		active = false
		audio_player.stream = EquipSound
		audio_player.play()
