extends Node

const Scene = preload("res://src/info/info_ui.tscn")
const TTL := 3.0

var current_inst: InfoUi
var timer := 0.0

func _process(delta: float) -> void:
	if current_inst != null:
		timer += delta

	if timer >= TTL and current_inst != null:
		current_inst.queue_free()
		timer = 0

func alert(message: String) -> void:
	if current_inst:
		current_inst.queue_free()

	var inst: InfoUi = Scene.instantiate()
	add_child(inst)
	inst.set_message(message)
	inst.set_size(Vector2(300, 150))

	current_inst = inst
