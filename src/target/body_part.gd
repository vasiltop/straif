class_name BodyPart extends StaticBody3D

@onready var owned_by: Target = get_parent()

var multiplier: float = 1.0

func apply_damage(amount: float) -> void:
	if not owned_by: return

	owned_by.health -= amount * multiplier

	if owned_by.health <= 0:
		owned_by.queue_free()
