class_name MapButtonOld extends Button

var map_name: String

func update_label(time: float) -> void:
	text = "%s\nPersonal Best: %s" % [map_name, str(snapped(time, 0.01))]
