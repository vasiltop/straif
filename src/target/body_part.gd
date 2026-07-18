class_name BodyPart extends Node3D

@export var owned_by: Node3D
@export var multiplier: float = 1.0

func apply_damage(amount: float, weapon_name: String) -> void:
	if not owned_by:
		return

	var to_apply := amount * multiplier

	if Global.mp():
		Global.mp_print("Sending damage to %d" % owned_by.pid)
		owned_by.on_damage.rpc_id(1, to_apply, weapon_name)
	else:
		if owned_by is Target:
			owned_by.apply_damage(to_apply)
		else:
			owned_by._apply_authoritative_damage(amount * multiplier, weapon_name, owned_by.pid)
