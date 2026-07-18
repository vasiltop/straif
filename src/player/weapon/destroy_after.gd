extends Decal

@export var ttl: float
var timer: float

func _process(delta: float) -> void:
	timer += delta

	if timer >= ttl:
		queue_free()
