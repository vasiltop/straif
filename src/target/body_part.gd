class_name BodyPart extends StaticBody3D

@onready var owned_by: Target = get_parent()

const DamageSound := preload("res://src/sounds/hit.mp3")

var multiplier: float = 1.0

func apply_damage(audio_player: AudioStreamPlayer, amount: float) -> void:
	if not owned_by: return

	owned_by.health -= amount * multiplier

	audio_player.stream = DamageSound
	audio_player.play()

	if owned_by.health <= 0:
		owned_by.queue_free()
