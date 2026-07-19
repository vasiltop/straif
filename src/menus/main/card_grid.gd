class_name CardGrid

static func fit(container: Control, cols: int) -> void:
	var sep: int = container.get_theme_constant("h_separation")
	var w := container.size.x
	if w <= 0.0:
		return
	var card_w := floori((w - sep * (cols - 1)) / cols)
	for c in container.get_children():
		if c is Control:
			(c as Control).custom_minimum_size.x = card_w
