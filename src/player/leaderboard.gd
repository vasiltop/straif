class_name Leaderboard extends Panel

@onready var entries := $Entries

func _ready() -> void:
	visible = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("leaderboard"):
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		for child in entries.get_children():
			child.queue_free()
		
		var run_position := 1
		var runs: Array = await Http.get_runs(Lobby.current_map.name, 0)

		for run: Dictionary in runs:
			var inst := Label.new()
			entries.add_child(inst)
			inst.text = "%d | %s - %s" % [run_position, run.username, str(snapped(run.time_ms / 1000, 0.001))]
			run_position += 1

			var btn := Button.new()
			if Lobby.admin:
				entries.add_child(btn)
				btn.text = "Watch Replay"

				btn.pressed.connect(func() -> void:
					var replay := await Http.get_replay(Lobby.current_map.name, run.steam_id as int)
					if replay != "":
						Lobby.replay_requested.emit(replay)
					else:
						print("Invalid replay request")
				)

		
	elif Input.is_action_just_released("leaderboard"):
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
