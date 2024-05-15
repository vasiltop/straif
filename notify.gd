extends Node

var notification_scene = preload("res://menus/notification.tscn")

func info(message: String):
	var n = create_notification()
	n.set_label(message)
	
func create_notification() -> Control:
	var i = notification_scene.instantiate()
	add_child(i)
	return i
