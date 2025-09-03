class_name BodyPart extends Node3D

@export var owned_by: Node3D
@export var multiplier: float = 1.0

const DamageSound := preload("res://src/sounds/hit.mp3")

func apply_damage(audio_player: AudioStreamPlayer, amount: float, weapon_name: String) -> void:
	if not owned_by: return

	owned_by.health -= amount * multiplier

	audio_player.stream = DamageSound
	audio_player.play()

	if Global.mp():
		Global.mp_print("Sending damage to %d" % owned_by.pid)
		owned_by.on_damage.rpc_id(1, amount * multiplier, weapon_name)
		owned_by.on_damage.rpc_id(owned_by.pid, amount * multiplier, weapon_name)

	if owned_by.health <= 0:
		owned_by.on_death()
