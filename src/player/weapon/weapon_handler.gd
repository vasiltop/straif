class_name WeaponHandler extends Node3D

@onready var player: Player = $"../../.."
@onready var weapon_scene: Node3D = null
@onready var raycast: RayCast3D = $RayCast
@onready var r_hand_ik: SkeletonIK3D = $arms/ArmArmature/Skeleton3D/RHandIk
@onready var l_hand_ik: SkeletonIK3D = $arms/ArmArmature/Skeleton3D/LHandIk
@onready var start_pos := position
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

@export var sway_left: Vector3
@export var sway_right: Vector3
@export var sway_left_rot: Vector3
@export var sway_right_rot: Vector3

const MAX_SWAY := 5
const SWAY_LERP := 1
const RAY_LENGTH := 1000
const BulletHoleScene := preload("res://src/player/weapon/bullet_hole.tscn")

var hit_sound: AudioStreamPlayer = AudioStreamPlayer.new()
var current_weapon: WeaponData = preload("res://src/player/weapon/rifle.tres") as WeaponData
var mouse_mov := 0.0
var time_since_last_shot: float = 0

func _ready() -> void:
	if not player.is_me(): return

	init_ik()

func set_weapon(weapon: WeaponData) -> void:
	current_weapon = weapon

	if weapon_scene:
		weapon_scene.queue_free()

	weapon_scene = weapon.scene.instantiate()
	add_child(weapon_scene)
	init_ik()

func _process(delta: float) -> void:
	if not player.is_me(): return

	if Input.is_action_just_pressed("attack"):
		_try_shoot()
	
	time_since_last_shot += delta
	
	_sway(delta)


func _sway(delta: float) -> void:
	var sway := start_pos
	var sway_rot := Vector3.ZERO

	if mouse_mov > MAX_SWAY:
		sway = sway_left + start_pos
		sway_rot = sway_left_rot
	elif mouse_mov < -MAX_SWAY:
		sway = sway_right + start_pos
		sway_rot = sway_right_rot

	position = position.lerp(sway, SWAY_LERP * delta)
	rotation = rotation.lerp(sway_rot, SWAY_LERP * delta)
	mouse_mov = 0

func _try_shoot() -> void:
	if current_weapon == null: return
	if not player.map or not player.map.running: return

	if time_since_last_shot < current_weapon.weapon_shot_delay:
		return
	
	time_since_last_shot = 0

	var anim: AnimationPlayer = weapon_scene.get_node("AnimationPlayer")
	anim.play("shoot")

	var muzzle_flash: GPUParticles3D = weapon_scene.get_node("MuzzleFlash")
	muzzle_flash.emitting = true

	audio_player.stream = current_weapon.shoot_sound
	audio_player.play()
	player.camera.shake(0.1, 0.005)
	
	var collider := raycast.get_collider()
	var hit_pos := Vector3.ZERO
	hit_pos = raycast.get_collision_point()
	
	BulletTracer.spawn(self, muzzle_flash.global_position, hit_pos)
	
	if not collider: return

	var inst: Decal = BulletHoleScene.instantiate()
	player.map.add_child(inst)
	inst.global_position = hit_pos

	# no clue what this does lol took it from reddit
	var normal :=  raycast.get_collision_normal()
	if normal != Vector3.UP:
		inst.look_at(hit_pos + normal, Vector3.UP)
		inst.transform = inst.transform.rotated_local(Vector3.RIGHT, PI/2.0)

	inst.rotate(normal, randf_range(0, 2*PI))

	if collider is BodyPart:
		var body_part: BodyPart = collider
		body_part.apply_damage(hit_sound, current_weapon.damage)

func _input(event: InputEvent) -> void:
	if not player.is_me(): return

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		mouse_mov = -motion.relative.x

func init_ik() -> void:
	if not weapon_scene: return

	var left_target := weapon_scene.get_node("LHandTarget").get_path()
	var right_target := weapon_scene.get_node("RHandTarget").get_path()
	
	r_hand_ik.target_node = right_target
	l_hand_ik.target_node = left_target

	r_hand_ik.start()
	l_hand_ik.start()
