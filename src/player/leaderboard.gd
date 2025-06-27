class_name Leaderboard extends Panel

@onready var entries := $Entries

func _ready() -> void:
	visible = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("leaderboard"):
		visible = true

		for child in entries.get_children():
			child.queue_free()
		
		var run_position := 1
		var runs: Array = (await Http.get_runs(Lobby.current_map.name, 0)).data

		for run: Dictionary in runs:
			var inst := Label.new()
			entries.add_child(inst)
			inst.text = "%d | %s - %s" % [run_position, run.username, str(snapped(run.time_ms / 1000, 0.001))]
			run_position += 1

		
	elif Input.is_action_just_released("leaderboard"):
		visible = false
