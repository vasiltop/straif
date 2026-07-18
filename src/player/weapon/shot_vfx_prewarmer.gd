extends Node

signal finished

const WEAPON_SCENES: Array[PackedScene] = [
	preload("res://src/player/weapon/scenes/ak47.tscn"),
	preload("res://src/player/weapon/scenes/rifle.tscn"),
	preload("res://src/player/weapon/scenes/shotgun.tscn"),
	preload("res://src/player/weapon/scenes/smg.tscn"),
	preload("res://src/player/weapon/scenes/sniper.tscn"),
	preload("res://src/player/weapon/scenes/usp.tscn"),
]
const TracerScene := preload("res://src/player/weapon/bullet_tracer.tscn")
const BulletHoleScene := preload("res://src/player/weapon/bullet_hole.tscn")
const BloodScene := preload("res://src/player/weapon/blood.tscn")
const WeaponShader := preload("res://src/player/weapon/scenes/weapon.gdshader")
const WARM_UP_FRAMES := 4

var _complete := false
var _running := false

func _ready() -> void:
	warm_up()

func warm_up() -> void:
	if _complete:
		return
	if _running:
		await finished
		return

	_running = true
	if DisplayServer.get_name() == "headless":
		_finish()
		return

	var viewport := _create_viewport()
	add_child(viewport)
	_add_vfx(viewport)

	for _frame in range(WARM_UP_FRAMES):
		await RenderingServer.frame_post_draw

	viewport.queue_free()
	await get_tree().process_frame
	_finish()

func is_complete() -> bool:
	return _complete

func _create_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.0, 3.0), Vector3.ZERO)
	camera.current = true

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	viewport.add_child(light)
	return viewport

func _add_vfx(viewport: SubViewport) -> void:
	var receiver := MeshInstance3D.new()
	var receiver_mesh := BoxMesh.new()
	receiver_mesh.size = Vector3(1.5, 1.5, 0.1)
	receiver.mesh = receiver_mesh
	receiver.position.z = -0.05
	viewport.add_child(receiver)

	for index in WEAPON_SCENES.size():
		var weapon := WEAPON_SCENES[index].instantiate()
		var source := weapon.get_node("MuzzleFlash") as GPUParticles3D
		var muzzle_flash := source.duplicate() as GPUParticles3D
		weapon.free()
		viewport.add_child(muzzle_flash)
		muzzle_flash.position = Vector3(-0.5 + float(index % 3) * 0.5, 0.45 - float(index / 3) * 0.5, 0.0)
		muzzle_flash.restart()
		muzzle_flash.emitting = true

	var tracer_scene := TracerScene.instantiate() as Node3D
	var tracer := tracer_scene.get_node("Mesh").duplicate(Node.DUPLICATE_USE_INSTANTIATION) as MeshInstance3D
	tracer_scene.free()
	viewport.add_child(tracer)
	tracer.position = Vector3(-0.35, -0.5, 0.1)

	var bullet_hole := BulletHoleScene.instantiate() as Decal
	viewport.add_child(bullet_hole)
	bullet_hole.position = Vector3.ZERO
	bullet_hole.rotation.x = PI / 2.0

	var blood_scene := BloodScene.instantiate() as Node3D
	var blood_source := blood_scene.get_node("CPUParticles3D") as CPUParticles3D
	var blood := blood_source.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as CPUParticles3D
	blood_scene.free()
	blood.set_script(null)
	viewport.add_child(blood)
	blood.position = Vector3(0.35, 0.0, 0.1)
	blood.one_shot = false
	blood.emitting = true
	blood.restart()

	var shader_mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = WeaponShader
	quad.material = shader_material
	shader_mesh.mesh = quad
	shader_mesh.position = Vector3(-0.35, 0.0, 0.1)
	viewport.add_child(shader_mesh)

func _finish() -> void:
	_running = false
	_complete = true
	print_verbose("Shot VFX prewarm completed.")
	finished.emit()
	call_deferred("queue_free")
