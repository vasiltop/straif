class_name BodyPart extends Node3D

@export var owned_by: Node3D
@export var multiplier: float = 1.0

func apply_damage(audio_player: AudioStreamPlayer3D, amount: float, weapon_name: String) -> void:
	if not owned_by: return

	owned_by.health -= amount * multiplier

	if Global.mp():
		Global.mp_print("Sending damage to %d" % owned_by.pid)
		owned_by.on_damage.rpc_id(1, amount * multiplier, weapon_name)
		owned_by.on_damage.rpc_id(owned_by.pid, amount * multiplier, weapon_name)

	if owned_by.health <= 0:
		owned_by.on_death()
