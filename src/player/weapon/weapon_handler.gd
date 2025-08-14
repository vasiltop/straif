class_name WeaponHandler extends Node3D

@onready var player: Player = $"../../.."
@onready var weapon_scene: Node3D = null
@onready var r_hand_ik: SkeletonIK3D = $Arms/ArmArmature/Skeleton3D/RHandIk
@onready var l_hand_ik: SkeletonIK3D = $Arms/ArmArmature/Skeleton3D/LHandIk
@onready var start_pos := position
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer
@onready var gun_container: Node3D = $GunContainer
@onready var arms: Node3D = $Arms

@export var sway_left: Vector3
@export var sway_right: Vector3
@export var sway_left_rot: Vector3
@export var sway_right_rot: Vector3
@export var sway_forward: Vector3
@export var sway_backward: Vector3
@export var sway_vertical: Vector3

const MAX_SWAY := 5
const SWAY_LERP := 2
const RAY_LENGTH := 1000
const BulletHoleScene := preload("res://src/player/weapon/bullet_hole.tscn")

var hit_sound: AudioStreamPlayer = AudioStreamPlayer.new()
var current_weapon: WeaponData
var mouse_mov := 0.0
var time_since_last_shot: float = 0

func _ready() -> void:
	if not player.is_me(): return

	init_ik()

func set_weapon(weapon: WeaponData) -> void:
	current_weapon = weapon

	if weapon_scene:
		weapon_scene.queue_free()

	if current_weapon != null:
		time_since_last_shot = current_weapon.weapon_shot_delay
		weapon_scene = weapon.scene.instantiate()
		gun_container.add_child(weapon_scene)

		# move it out of the way so it doesnt flicker
		weapon_scene.global_position = Vector3.ZERO

		init_ik()
		arms.visible = true

		var anim: AnimationPlayer = weapon_scene.get_node("AnimationPlayer")
		anim.play("equip")

		if current_weapon.is_melee:
			var hitbox: Area3D = weapon_scene.get_node("Mesh/Hitbox")
			hitbox.monitoring = false
			anim.animation_started.connect(_on_animation_started)
			anim.animation_finished.connect(_on_animation_finished)
			hitbox.body_entered.connect(_on_sword_hit)
	else:
		arms.visible = false

func _on_animation_started(anim_name: String) -> void:
	if anim_name == "shoot": 
		var hitbox: Area3D = weapon_scene.get_node("Mesh/Hitbox")
		hitbox.monitoring = true

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "shoot": 
		var hitbox: Area3D = weapon_scene.get_node("Mesh/Hitbox")
		hitbox.monitoring = false

func _on_sword_hit(body: Node3D) -> void:
	if body is BodyPart:
		var body_part: BodyPart = body
		body_part.apply_damage(hit_sound, current_weapon.damage)
		player.camera.shake(0.1, 0.03)

func _process(delta: float) -> void:
	if not player.is_me(): return
	if not current_weapon: return

	var attack_input := Input.is_action_just_pressed("attack") if not current_weapon.automatic else Input.is_action_pressed("attack")
	if attack_input and time_since_last_shot > current_weapon.weapon_shot_delay:
		for i in range(current_weapon.bullet_count):
			_try_shoot()
		time_since_last_shot = 0
	
	if current_weapon and Input.is_action_just_pressed("inspect"):
		var anim: AnimationPlayer = weapon_scene.get_node("AnimationPlayer")

		if anim.is_playing() and anim.current_animation == "shoot" and current_weapon.is_melee:
			var hitbox: Area3D = weapon_scene.get_node("Mesh/Hitbox")
			hitbox.monitoring = false

		anim.play("inspect")
	
	if current_weapon and Input.is_action_just_pressed("scope") and current_weapon.is_sniper:
		toggle_sniper_scope()
	
	time_since_last_shot += delta

func toggle_sniper_scope() -> void:
	player.sniper_overlay.visible = not player.sniper_overlay.visible
	visible = not visible
	const FOV_DIFF := 45
	
	match player.sniper_overlay.visible:
		true:
			player.camera.fov -= FOV_DIFF
		false:
			player.camera.fov += FOV_DIFF
	
	# TODO: Add ADS sound.
	#audio_player.stream = ADS_SOUND
	#audio_player.play()

func _physics_process(delta: float) -> void:
	_sway(delta)

func _sway(delta: float) -> void:
	var sway_rot := Vector3.ZERO
	var sway_add := Vector3.ZERO

	if mouse_mov > MAX_SWAY || Input.is_action_pressed("left"):
		sway_add += sway_left
		sway_rot += sway_left_rot
	if mouse_mov < -MAX_SWAY || Input.is_action_pressed("right"):
		sway_add += sway_right
		sway_rot += sway_right_rot
	if Input.is_action_pressed("up"):
		sway_add += sway_forward
	if Input.is_action_pressed("down"):
		sway_add += sway_backward
	
	sway_add += sway_vertical * sign(player.velocity.y)
	var sway := start_pos + sway_add

	position = position.lerp(sway, SWAY_LERP * delta)
	rotation = rotation.lerp(sway_rot, SWAY_LERP * delta)
	mouse_mov = 0

func _try_shoot() -> void:
	if not player.map: return
	if not player.map.running and not player.map.completed: return

	var anim: AnimationPlayer = weapon_scene.get_node("AnimationPlayer")
	if anim.current_animation == "inspect" or not anim.is_playing():
		anim.play("shoot")

	var tracer_pos := Vector3.ZERO
	if not current_weapon.is_melee:
		var muzzle_flash: GPUParticles3D = weapon_scene.get_node("MuzzleFlash")
		muzzle_flash.emitting = true
		tracer_pos = muzzle_flash.global_position

	if current_weapon.shoot_sound:
		audio_player.stream = current_weapon.shoot_sound
		audio_player.play()

	if current_weapon.is_melee: 
		return

	var rad := deg_to_rad(current_weapon.recoil / 2)
	player.camera._mouse_input.y += deg_to_rad(current_weapon.recoil)
	player.camera._mouse_input.x = randf_range(-rad, rad)
	
	var spread := current_weapon.spread if not player.sniper_overlay.visible else 0.0
	if current_weapon.is_sniper and player.sniper_overlay.visible:
		toggle_sniper_scope()
	
	var origin := player.camera.global_transform.origin
	var direction := -player.camera.global_transform.basis.z.normalized()
	var distance := current_weapon.attack_range

	if spread != 0.0:
		var rand_radians := func() -> float: return deg_to_rad(randf_range(-spread, spread)) 
		var rand_rot_x: float = rand_radians.call()
		var rand_rot_y: float = rand_radians.call()
		var rand_rot_z: float = rand_radians.call()
		
		var spread_basis := Basis()
		spread_basis = spread_basis.rotated(Vector3.RIGHT, rand_rot_x)
		spread_basis = spread_basis.rotated(Vector3.UP, rand_rot_y)
		spread_basis = spread_basis.rotated(Vector3.BACK, rand_rot_z)

		direction = (spread_basis * direction).normalized()

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction*distance)
	var result := space_state.intersect_ray(query)
	var hit_pos := origin + direction * distance
	
	if result != {}:
		hit_pos = result.position
		var collider: Object = result.collider

		var inst: Decal = BulletHoleScene.instantiate()
		player.map.add_child(inst)
		inst.global_position = hit_pos

		# no clue what this does lol took it from reddit
		var normal: Vector3 = result.normal
		if normal != Vector3.UP:
			inst.look_at(hit_pos + normal, Vector3.UP)
			inst.transform = inst.transform.rotated_local(Vector3.RIGHT, PI/2.0)

		inst.rotate(normal, randf_range(0, 2*PI))

		if collider is BodyPart:
			var body_part: BodyPart = collider
			body_part.apply_damage(hit_sound, current_weapon.damage)
	
	if not current_weapon.is_melee:
			BulletTracer.spawn(self, tracer_pos, hit_pos)

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
