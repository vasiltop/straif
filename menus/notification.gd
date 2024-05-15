extends Control
var timer: float = 3

func set_label(message: String):
	$ColorRect/Label.text = message
	
func _process(delta):
	timer -= delta
	
	if timer < 0:
		queue_free()
