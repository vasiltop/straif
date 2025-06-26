class_name BulletTracer extends Node3D

const SPEED := 300.0
const TracerScene := preload("res://src/player/weapon/bullet_tracer.tscn")
const LENGTH := 1.0
const TTL := 5000

@onready var spawn_time := Time.get_ticks_msec()
var target: Vector3

# if target is Vector3.ZERO we treat it as if the bullet did not hit anything
static func spawn(parent: Node, spawn_position: Vector3, target: Vector3) -> void:
	var inst: BulletTracer = TracerScene.instantiate()
	inst.target = target
	parent.add_child(inst)

	inst.global_position = spawn_position
	inst.look_at(target)

func _process(delta: float) -> void:
	var diff := target - global_position
	var add := diff.normalized() * SPEED * delta
	add = add.limit_length(diff.length())

	global_position += add

	if (target - global_position).length() <= LENGTH or Time.get_ticks_msec() - spawn_time > TTL:
		queue_free()
