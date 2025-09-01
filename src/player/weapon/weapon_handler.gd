class_name WeaponHandler extends Node3D

signal shot(mag_ammo: int, reserve_ammo: int)

@onready var player: Player = $"../../.."
@onready var weapon_scene: Node3D = null
@onready var r_hand_ik: SkeletonIK3D = $Arms/Armature/Skeleton3D/RHandIk
@onready var l_hand_ik: SkeletonIK3D = $Arms/Armature/Skeleton3D/LHandIk
@onready var r_hand_ik_tp: SkeletonIK3D = $"../../../ThirdPerson/Model/FullArmature/Skeleton3D/RHandIk"
@onready var l_hand_ik_tp: SkeletonIK3D = $"../../../ThirdPerson/Model/FullArmature/Skeleton3D/LHandIk"

@onready var start_pos := position
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer
@onready var gun_container: Node3D = $GunContainer
@onready var arms: Node3D = $Arms
@onready var weapon_pos_tp: Marker3D = $"../../../ThirdPerson/WeaponPosTP"

@export var sway_left: Vector3
@export var sway_right: Vector3
@export var sway_left_rot: Vector3
@export var sway_right_rot: Vector3
@export var sway_forward: Vector3
@export var sway_backward: Vector3
@export var sway_vertical: Vector3
@export var recoil_reset_time: float
@export var recoil_reset_speed: float

const MAX_SWAY := 5
const SWAY_LERP := 2
const RAY_LENGTH := 1000
const BulletHoleScene := preload("res://src/player/weapon/bullet_hole.tscn")
const BloodScene := preload("res://src/player/weapon/blood.tscn")
const ReloadSound = preload("res://src/sounds/reload.wav")

var audio: AudioStreamPlayer = AudioStreamPlayer.new()
var current_weapon: WeaponData
var mouse_mov := 0.0
var time_since_last_shot: float = 0
var mag_ammo := 0
var reserve_ammo := 0
var max_mag_ammo := 0
var current_recoil: Vector2

@rpc("any_peer", "call_local", "reliable")
func set_weapon_to_index(index: int, is_tp := false) -> void:
	var weapon := Global.game_manager.get_weapon_from_index(index)
	set_weapon(weapon, is_tp)

@rpc("any_peer", "call_local", "reliable")
func set_weapon(weapon: WeaponData, is_third_person := false) -> void:
	current_weapon = weapon

	if weapon_scene:
		weapon_scene.queue_free()
		
	if current_weapon != null:
		time_since_last_shot = current_weapon.weapon_shot_delay
		weapon_scene = weapon.scene.instantiate()
		mag_ammo = current_weapon.mag_ammo
		max_mag_ammo = mag_ammo
		reserve_ammo = current_weapon.reserve_ammo
		shot.emit(mag_ammo, reserve_ammo)
		
		# move it out of the way so it doesnt flicker
		weapon_scene.global_position = Vector3.ZERO
		
		var gun_parent := gun_container
		if is_third_person: 
			gun_parent = weapon_pos_tp
			var mesh := weapon_scene.get_node("Mesh") as MeshInstance3D
			mesh.set_layer_mask_value(1, true)
			mesh.set_layer_mask_value(2, false)
			weapon_scene.scale *= 0.4
			
			var muzzle_flash := weapon_scene.get_node("MuzzleFlash") as GPUParticles3D
			muzzle_flash.set_layer_mask_value(1, true)
			muzzle_flash.set_layer_mask_value(2, false)
			
		gun_parent.add_child(weapon_scene)

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
		
	init_ik(is_third_person)
	#Global.mp_print("Set players weapon to %s" % weapon.name)

func _on_animation_started(anim_name: String) -> void:
	if anim_name == "shoot" and player.is_me(): 
		var hitbox: Area3D = weapon_scene.get_node("Mesh/Hitbox")
		hitbox.monitoring = true

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "shoot": 
		var hitbox: Area3D = weapon_scene.get_node("Mesh/Hitbox")
		hitbox.monitoring = false

func _on_sword_hit(body: Node3D) -> void:
	if body is BodyPart:
		if body.owned_by is Player and body.owned_by.is_me(): return
		
		body.apply_damage(audio, current_weapon.damage)
		player.camera.shake(0.1, 0.03)

func _process(delta: float) -> void:
	time_since_last_shot += delta
	
	if not player.is_me(): return
	_handle_inputs()
	
	if time_since_last_shot >= recoil_reset_time:
		var dx := current_recoil.x * recoil_reset_speed / 100.0
		var dy := current_recoil.y * recoil_reset_speed / 100.0
		
		player.camera._mouse_input.y -= dy * delta
		player.camera._mouse_input.x -= dx * delta
		
		current_recoil.x -= dx * delta
		current_recoil.y -= dy * delta

func attack_input() -> bool:
	if not current_weapon: return false
	return Input.is_action_just_pressed("attack") if not current_weapon.automatic else Input.is_action_pressed("attack")

func _handle_inputs() -> void:
	if not player.is_me(): return
	if not current_weapon: return
	if not player.can_move: return

	if attack_input():
		_try_shoot()

	if Input.is_action_just_pressed("inspect"):
		var anim: AnimationPlayer = weapon_scene.get_node("AnimationPlayer")

		if anim.is_playing() and anim.current_animation == "shoot" and current_weapon.is_melee:
			var hitbox: Area3D = weapon_scene.get_node("Mesh/Hitbox")
			hitbox.monitoring = false

		anim.play("inspect")
	
	if Input.is_action_just_pressed("scope") and current_weapon.is_sniper:
		toggle_sniper_scope()
		
	if Input.is_action_just_pressed("reload") and not current_weapon.is_melee and not mag_ammo == max_mag_ammo and reserve_ammo > 0:
		reload()

func reload() -> void:
	if Global.mp():
		reload_anim.rpc()
	else:
		reload_anim()
	
	reserve_ammo += mag_ammo
	var v := min(max_mag_ammo, reserve_ammo)
	mag_ammo = v
	reserve_ammo -= v
	
	shot.emit(mag_ammo, reserve_ammo)
	
	audio_player.stream = ReloadSound
	audio_player.play()

@rpc("any_peer", "call_local", "unreliable")
func reload_anim() -> void:
	var audio_player: AnimationPlayer = weapon_scene.get_node("AnimationPlayer")
	audio_player.play("equip")
	
func toggle_sniper_scope() -> void:
	player.sniper_overlay.visible = not player.sniper_overlay.visible
	visible = not visible
	const FOV_DIFF := 45
	
	match player.sniper_overlay.visible:
		true:
			player.camera.fov -= FOV_DIFF
		false:
			player.camera.fov += FOV_DIFF

func _physics_process(delta: float) -> void:
	if not player.is_me(): return
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

@rpc("call_local", "any_peer", "unreliable")
func _attack_visuals() -> void:
	var anim: AnimationPlayer = weapon_scene.get_node("AnimationPlayer")
	if anim.current_animation == "inspect" or not anim.is_playing():
		anim.play("shoot")
		
	audio_player.stream = current_weapon.shoot_sound
	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play()

func can_shoot(ghost_bullet: bool) -> bool:
	if current_weapon == null: return false
	if mag_ammo <= 0 and not ghost_bullet: return false
	if time_since_last_shot < current_weapon.weapon_shot_delay: return false
	
	return true

func _try_shoot(ghost_bullet := false) -> void:
	if not can_shoot(ghost_bullet): return
	
	var anim: AnimationPlayer = weapon_scene.get_node("AnimationPlayer")
	if anim.current_animation == "equip": return
	
	time_since_last_shot = 0
	
	if Global.mp():
		_attack_visuals.rpc()
	else:
		_attack_visuals()
	
	if current_weapon.is_melee: return
	
	mag_ammo -= 1
	shot.emit(mag_ammo, reserve_ammo)
	
	for i in range(current_weapon.bullet_count):
		_shoot_bullet(ghost_bullet)

@rpc("call_local", "any_peer", "unreliable")
func _gun_visuals(hit_pos: Vector3) -> void:
	var muzzle_flash: GPUParticles3D = weapon_scene.get_node("MuzzleFlash")
	muzzle_flash.emitting = true

	var tracer_pos: Vector3 = weapon_scene.get_node("MuzzleFlash").global_position
	BulletTracer.spawn(player, tracer_pos, hit_pos)

@rpc("call_local", "any_peer", "unreliable")
func _spawn_bullet_hole(pos: Vector3, normal: Vector3) -> void:
	var inst: Decal = BulletHoleScene.instantiate()
	player.add_child(inst)
	inst.global_position = pos
	
	# no clue what this does lol took it from reddit
	if normal != Vector3.UP:
		inst.look_at(pos + normal, Vector3.UP)
		inst.transform = inst.transform.rotated_local(Vector3.RIGHT, PI/2.0)

	inst.rotate(normal, randf_range(0, 2*PI))

@rpc("call_local", "any_peer", "unreliable")
func _spawn_blood(hit_pos: Vector3) -> void:
	var inst: Node3D = BloodScene.instantiate()
	player.add_child(inst)
	inst.global_position = hit_pos

func _shoot_bullet(ghost_bullet := false) -> void:
	var rad := deg_to_rad(current_weapon.recoil / 2)
	
	var rec_y := deg_to_rad(current_weapon.recoil)
	current_recoil.y += rec_y
	player.camera._mouse_input.y += rec_y

	var rec_x := randf_range(-rad, rad)
	current_recoil.x += rec_x
	player.camera._mouse_input.x += rec_x

	var spread := current_weapon.spread if not player.sniper_overlay.visible else 0.0
	if not player.grounded() and player.hardcore:
		spread = current_weapon.moving_spread

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
	query.collision_mask = 1 << 0 | 1 << 2
	var result := space_state.intersect_ray(query)
	var hit_pos := origin + direction * distance
	
	if result != {}:
		hit_pos = result.position
		var collider = result.collider
		
		if collider is BodyPart:
			var body_part: BodyPart = collider
			
			if not ghost_bullet:
				body_part.apply_damage(audio, current_weapon.damage)
				
			if Global.mp():
				_spawn_blood.rpc(hit_pos)
			else:
				_spawn_blood(hit_pos)
		elif collider is not BodyPart:	
			if Global.mp():
				_spawn_bullet_hole.rpc(hit_pos, result.normal)
			else:
				_spawn_bullet_hole(hit_pos, result.normal)
	
	if Global.mp():
		_gun_visuals.rpc(hit_pos)
	else:
		_gun_visuals(hit_pos)
		
func _input(event: InputEvent) -> void:
	if not player.is_me(): return

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		mouse_mov = -motion.relative.x

func init_ik(is_third_person: bool) -> void:
	var rik = r_hand_ik_tp if is_third_person else r_hand_ik
	var lik = l_hand_ik_tp if is_third_person else l_hand_ik
	
	if not player.is_me():
		print(current_weapon, is_third_person)
	
	if not current_weapon:
		rik.stop()
		lik.stop()
		return

	var left_target := weapon_scene.get_node("LHandTarget").get_path()
	var right_target := weapon_scene.get_node("RHandTarget").get_path()
	
	rik.target_node = right_target
	lik.target_node = left_target

	rik.start()
	lik.start()
