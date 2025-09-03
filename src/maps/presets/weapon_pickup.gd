class_name WeaponPickup extends Area3D

@onready var weapon_spawn: Node3D = $WeaponSpawn
@export var weapon: WeaponData
@onready var map: Map = $"../.."

const EquipSound = preload("res://src/sounds/equip.mp3")

var audio_player := AudioStreamPlayer.new()
var weapon_scene: Node3D
var active := true
var is_touching_player := false
var currently_touching: Player
var frame_picked_up := -1
var previous_weapon: WeaponData

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
			if body is Player and body.is_me():
				currently_touching = body
				is_touching_player = true
	)
	
	body_exited.connect(
		func(body: Node3D) -> void:
			if body is Player and body.is_me():
				is_touching_player = false
	)

func reset() -> void:
	weapon_scene.visible = true
	active = true
	is_touching_player = false
	frame_picked_up = -1

func _process(delta: float) -> void:
	if not active: return
	
	weapon_scene.rotate_y(deg_to_rad(45 * delta))
	weapon_scene.global_position.y = weapon_spawn.global_position.y + sin(float(Time.get_ticks_msec()) / 1000) / 7
	
	if is_touching_player:
		frame_picked_up = map.recorder.current_frame
		previous_weapon = currently_touching.weapon_handler.current_weapon
		currently_touching.weapon_handler.set_weapon(weapon)
		#audio_player.stream = EquipSound
		#audio_player.play()
		deactivate()

func deactivate() -> void:
	weapon_scene.visible = false
	active = false
