class_name DmUi extends CanvasLayer

@export var killfeed: VBoxContainer

const MAX_KILLFEED_LENGTH := 5
const KILLFEED_FONT_SIZE := 15
const KILLFEED_TTL := 5.0

var time_since_last_kill := 0.0

func _process(delta: float) -> void:
	time_since_last_kill += delta
	
	if time_since_last_kill >= KILLFEED_TTL:
		killfeed.visible = false
		for child in killfeed.get_children():
			child.queue_free()

@rpc("authority", "call_local", "reliable")
func log_kill(killer_name: String, player_name: String) -> void:
	var count := killfeed.get_child_count()
	if count >= MAX_KILLFEED_LENGTH:
		killfeed.get_child(0).queue_free()
	
	killfeed.visible = true
	time_since_last_kill = 0.0
	
	var label := Label.new()
	label.text = "Player %s has eliminated %s!" % [killer_name, player_name]
	killfeed.add_child(label)
	label.add_theme_font_size_override("font_size", KILLFEED_FONT_SIZE)
