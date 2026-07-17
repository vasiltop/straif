class_name AimTrainer
extends Node3D

const MAIN_MENU_SCENE := "res://src/menus/main/main_menu.tscn"
const PLAYER_SCENE_PATH := "res://src/player/player.tscn"
const VALID_SCENARIOS := ["gridshot", "flick", "tracking"]
const SESSION_DURATION := 60.0
const COUNTDOWN_DURATION := 3.0
const PLAYER_RESET_HEALTH := 100.0
const GRIDSHOT_COLUMNS := 3
const GRIDSHOT_ROWS := 3
const GRIDSHOT_SPACING := Vector2(2.4, 1.55)
const GRIDSHOT_WAVE_BONUS := 250
const FLICK_MIN_REPOSITION_DISTANCE := 1.35
const TRACKING_SAMPLE_INTERVAL := 0.05
const TRACKING_REACQUIRE_DELAY := 0.2
const TRACKING_SCORE_PER_SAMPLE := 8

@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var aim_targets: Node3D = $AimTargets
@onready var target_wall_anchor: Marker3D = $TargetWallAnchor
@onready var primary_panel: Panel = $HUD/PrimaryPanel
@onready var timer_label: Label = $HUD/PrimaryPanel/TimerLabel
@onready var score_label: Label = $HUD/PrimaryPanel/ScoreLabel
@onready var secondary_panel: Panel = $HUD/SecondaryPanel
@onready var scenario_label: Label = $HUD/SecondaryPanel/ScenarioLabel
@onready var hits_label: Label = $HUD/SecondaryPanel/HitsLabel
@onready var misses_label: Label = $HUD/SecondaryPanel/MissesLabel
@onready var accuracy_label: Label = $HUD/SecondaryPanel/AccuracyLabel
@onready var reaction_label: Label = $HUD/SecondaryPanel/ReactionLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var results_panel: Panel = $HUD/ResultsPanel
@onready var results_score_label: Label = $HUD/ResultsPanel/ResultsScoreLabel
@onready var results_stats_label: Label = $HUD/ResultsPanel/ResultsStatsLabel
@onready var leaderboard_status: Label = $HUD/ResultsPanel/LeaderboardStatus
@onready var leaderboard_rows: VBoxContainer = $HUD/ResultsPanel/LeaderboardRows
@onready var retry_button: Button = $HUD/ResultsPanel/RetryButton
@onready var main_menu_button: Button = $HUD/ResultsPanel/MainMenuButton

var player = null
var selected_scenario := "gridshot"
var session_started := false
var session_finished := false
var countdown_remaining := COUNTDOWN_DURATION
var session_time_remaining := SESSION_DURATION
var score := 0
var hits := 0
var misses := 0
var reaction_samples: Array[float] = []
var active_targets: Array = []
var grid_wave_started_at := 0.0
var last_flick_position := Vector3.ZERO
var tracking_target = null
var tracking_sample_accumulator := 0.0
var tracking_has_contact := false
var tracking_pending_reaction_started_at := 0.0
var tracking_loss_started_at := -1.0
var rng := RandomNumberGenerator.new()
var spawn_position := Vector3.ZERO
var spawn_rotation := Vector3.ZERO
var results_request_generation := 0

func _ready() -> void:
	rng.randomize()
	var global_node = _global_node()
	if global_node != null:
		global_node.multiplayer.multiplayer_peer = null
	selected_scenario = _resolve_scenario()
	player = _spawn_player()
	spawn_position = player.global_position
	spawn_rotation = player.global_rotation

	if player.weapon_handler.audio.get_parent() != null:
		player.weapon_handler.audio.get_parent().remove_child(player.weapon_handler.audio)

	player.setup()
	player.hardcore = false
	player.weapon_handler.set_weapon_to_index(1)
	player.weapon_handler.bullet_fired.connect(_on_bullet_fired)
	player.toggled_pause.connect(_on_player_toggled_pause)
	retry_button.pressed.connect(retry_session)
	main_menu_button.pressed.connect(_go_to_main_menu)

	retry_session()

func _process(delta: float) -> void:
	if player == null:
		return
	if player.is_paused():
		return
	if session_finished:
		return

	if not session_started:
		countdown_remaining = maxf(countdown_remaining - delta, 0.0)
		if is_zero_approx(countdown_remaining):
			_start_session()
	else:
		session_time_remaining = maxf(session_time_remaining - delta, 0.0)
		if selected_scenario == "tracking":
			tracking_sample_accumulator += delta
			while tracking_sample_accumulator >= TRACKING_SAMPLE_INTERVAL:
				tracking_sample_accumulator -= TRACKING_SAMPLE_INTERVAL
				_sample_tracking()
		if is_zero_approx(session_time_remaining):
			_end_session()

	_refresh_hud()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if not _is_session_active():
		return
	if player.is_paused():
		return
	if selected_scenario != "tracking":
		return
	if tracking_target == null:
		return

	tracking_target.update_tracking_motion(delta)

func retry_session() -> void:
	results_request_generation += 1
	selected_scenario = _resolve_scenario()
	session_started = false
	session_finished = false
	countdown_remaining = COUNTDOWN_DURATION
	session_time_remaining = SESSION_DURATION
	score = 0
	hits = 0
	misses = 0
	reaction_samples.clear()
	active_targets.clear()
	tracking_target = null
	tracking_sample_accumulator = 0.0
	tracking_has_contact = false
	tracking_pending_reaction_started_at = 0.0
	tracking_loss_started_at = -1.0
	grid_wave_started_at = 0.0
	last_flick_position = target_wall_anchor.global_position

	_clear_targets()
	_clear_leaderboard_rows()
	leaderboard_status.text = "Results will submit when the session ends"
	results_panel.visible = false
	primary_panel.visible = true
	secondary_panel.visible = true

	if player.pause_menu.visible:
		player.toggle_pause()

	player.global_position = spawn_position
	player.global_rotation = spawn_rotation
	player.velocity = Vector3.ZERO
	player.health = PLAYER_RESET_HEALTH
	player.can_move = true
	player.can_turn = true
	player.camera._input_rotation = Vector3.ZERO
	player.camera._mouse_input = Vector2.ZERO
	player.camera_anchor.rotation = Vector3.ZERO
	player.sniper_overlay.visible = false
	player.weapon_handler.reset_ammo()
	player.weapon_handler.shooting_enabled = false
	player.weapon_handler.visible = true
	player.ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_refresh_hud()

func calculate_accuracy(hit_total: int, miss_total: int) -> float:
	var attempts := hit_total + miss_total
	if attempts <= 0:
		return 0.0
	return (float(hit_total) / float(attempts)) * 100.0

func calculate_average_reaction_ms(samples: Array) -> float:
	if samples.is_empty():
		return 0.0

	var total := 0.0
	for sample in samples:
		total += float(sample)
	return (total / float(samples.size())) * 1000.0

func show_leaderboard_rows(rows: Array) -> void:
	_clear_leaderboard_rows()
	if rows.is_empty():
		return

	for index in range(rows.size()):
		var row_data = rows[index]
		var entry := HBoxContainer.new()
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_constant_override("separation", 12)

		var rank_label := Label.new()
		var name_label := Label.new()
		var value_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if row_data is Dictionary:
			rank_label.text = str(row_data.get("rank", index + 1))
			name_label.text = str(row_data.get("name", row_data.get("player", "Player")))
			if row_data.has("accuracy") or row_data.has("reaction"):
				value_label.text = "%s pts · %s · %s" % [
					str(row_data.get("score", row_data.get("value", ""))),
					str(row_data.get("accuracy", "--")),
					str(row_data.get("reaction", "--"))
				]
			else:
				value_label.text = str(row_data.get("score", row_data.get("value", "")))
		else:
			rank_label.text = str(index + 1)
			name_label.text = str(row_data)
			value_label.text = ""

		entry.add_child(rank_label)
		entry.add_child(name_label)
		entry.add_child(value_label)
		leaderboard_rows.add_child(entry)

func show_leaderboard_error(message: String) -> void:
	_clear_leaderboard_rows()
	leaderboard_status.text = message

func _spawn_player():
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var player_instance = player_scene.instantiate()
	player_instance.name = "Player"
	add_child(player_instance)
	move_child(player_instance, aim_targets.get_index() + 1)
	player_instance.global_position = player_spawn.global_position
	player_instance.global_rotation = player_spawn.global_rotation
	return player_instance

func _resolve_scenario() -> String:
	var global_node = _global_node()
	if global_node != null and global_node.game_manager != null:
		var configured = global_node.game_manager.get_current_aim_scenario()
		if configured in VALID_SCENARIOS:
			return configured
	return VALID_SCENARIOS[0]

func _global_node():
	return get_node_or_null("/root/Global")

func _start_session() -> void:
	session_started = true
	session_finished = false
	session_time_remaining = SESSION_DURATION
	tracking_sample_accumulator = 0.0
	tracking_has_contact = false
	tracking_pending_reaction_started_at = 0.0
	tracking_loss_started_at = -1.0
	player.can_move = true
	player.can_turn = true
	player.weapon_handler.shooting_enabled = selected_scenario != "tracking"
	_clear_targets()

	match selected_scenario:
		"gridshot":
			_spawn_gridshot_wave()
		"flick":
			_spawn_flick_target()
		"tracking":
			_spawn_tracking_target()

	_refresh_hud()

func _end_session() -> void:
	session_finished = true
	session_started = false
	player.weapon_handler.shooting_enabled = false
	player.can_move = false
	player.can_turn = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_hud()
	_update_results_panel()
	results_panel.visible = true
	_submit_results_and_load_leaderboard(results_request_generation)

func _spawn_gridshot_wave() -> void:
	_clear_targets()
	active_targets.clear()
	grid_wave_started_at = _session_elapsed()
	for target_position in _grid_positions():
		var target = _create_target(target_position)
		active_targets.append(target)

func _spawn_flick_target() -> void:
	active_targets.clear()
	var target = _create_target(_next_flick_position())
	active_targets.append(target)

func _spawn_tracking_target() -> void:
	active_targets.clear()
	tracking_target = _create_target(target_wall_anchor.global_position)
	tracking_target.configure_tracking_motion(target_wall_anchor.global_position, Vector2(3.4, 1.55), 1.15, Vector2(rng.randf_range(0.0, PI), rng.randf_range(0.0, PI)))
	active_targets.append(tracking_target)
	tracking_pending_reaction_started_at = 0.0

func _create_target(target_position: Vector3):
	var target_scene := load("res://src/maps/aim/aim_target.tscn") as PackedScene
	var target = target_scene.instantiate()
	aim_targets.add_child(target)
	target.activate(target_position, _session_elapsed())
	return target

func _grid_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var x_offset := GRIDSHOT_SPACING.x
	var y_offset := GRIDSHOT_SPACING.y
	for row in GRIDSHOT_ROWS:
		for column in GRIDSHOT_COLUMNS:
			var local_position := Vector3(
				(float(column) - 1.0) * x_offset,
				(1.0 - float(row)) * y_offset,
				0.0
			)
			positions.append(target_wall_anchor.global_position + local_position)
	return positions

func _next_flick_position() -> Vector3:
	var candidate := target_wall_anchor.global_position
	for _attempt in 8:
		candidate = target_wall_anchor.global_position + Vector3(
			rng.randf_range(-3.6, 3.6),
			rng.randf_range(-1.8, 1.8),
			0.0
		)
		if candidate.distance_to(last_flick_position) >= FLICK_MIN_REPOSITION_DISTANCE:
			break
	last_flick_position = candidate
	return candidate

func _on_bullet_fired(collider: Object, hit_position: Vector3) -> void:
	if not _is_session_active():
		return
	if selected_scenario == "tracking":
		return

	var target = null
	if collider is Node and collider.is_in_group("aim_target"):
		target = collider

	if target != null and target.active:
		if _handle_target_hit(target, hit_position):
			_refresh_hud()
			return

		misses += 1
	else:
		misses += 1

	_refresh_hud()

func _handle_target_hit(target, hit_position: Vector3) -> bool:
	var current_time := _session_elapsed()
	if not target.register_hit(hit_position, current_time):
		return false

	hits += 1
	var reaction_time := maxf(current_time - target.available_since, 0.0)
	reaction_samples.append(reaction_time)

	match selected_scenario:
		"gridshot":
			score += _gridshot_hit_score(reaction_time)
			if _all_grid_targets_cleared():
				score += _gridshot_wave_bonus(current_time - grid_wave_started_at)
				_spawn_gridshot_wave()
		"flick":
			score += _flick_hit_score(reaction_time)
			target.activate(_next_flick_position(), current_time)

	return true

func _all_grid_targets_cleared() -> bool:
	for target in active_targets:
		if target.active:
			return false
	return true

func _gridshot_hit_score(reaction_time: float) -> int:
	return 100 + int(clampf((1.15 - reaction_time) * 160.0, 0.0, 240.0))

func _gridshot_wave_bonus(clear_time: float) -> int:
	return GRIDSHOT_WAVE_BONUS + int(clampf((4.0 - clear_time) * 120.0, 0.0, 420.0))

func _flick_hit_score(reaction_time: float) -> int:
	return 160 + int(clampf((1.0 - reaction_time) * 220.0, 0.0, 320.0))

func _sample_tracking() -> void:
	var space_state := get_world_3d().direct_space_state
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = -player.camera.global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	query.collision_mask = 4
	var result := space_state.intersect_ray(query)
	var current_time := _session_elapsed()
	var on_target := false
	if result != {}:
		on_target = result.collider == tracking_target and tracking_target != null and tracking_target.active

	if on_target:
		hits += 1
		score += TRACKING_SCORE_PER_SAMPLE
		if not tracking_has_contact:
			if tracking_loss_started_at < 0.0 or current_time - tracking_loss_started_at >= TRACKING_REACQUIRE_DELAY:
				reaction_samples.append(maxf(current_time - tracking_pending_reaction_started_at, 0.0))
			tracking_has_contact = true
			tracking_loss_started_at = -1.0
	else:
		misses += 1
		if tracking_has_contact:
			tracking_has_contact = false
			tracking_loss_started_at = current_time
			tracking_pending_reaction_started_at = current_time

func _session_elapsed() -> float:
	return SESSION_DURATION - session_time_remaining

func _is_session_active() -> bool:
	return session_started and not session_finished

func _clear_targets() -> void:
	for child in aim_targets.get_children():
		child.free()

func _clear_leaderboard_rows() -> void:
	for child in leaderboard_rows.get_children():
		child.free()

func _lock_finished_session_controls() -> void:
	player.can_move = false
	player.can_turn = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_player_toggled_pause(value: bool) -> void:
	if session_finished:
		_lock_finished_session_controls()
		call_deferred("_lock_finished_session_controls")
		return

	player.can_move = not value
	if value:
		status_label.text = "Paused"
	else:
		_refresh_hud()

func _refresh_hud() -> void:
	timer_label.text = "TIME\n%.1f" % session_time_remaining
	score_label.text = "SCORE\n%d" % score
	scenario_label.text = "SCENARIO\n%s" % selected_scenario.to_upper()
	hits_label.text = "HITS\n%d" % hits
	misses_label.text = "MISSES\n%d" % misses
	accuracy_label.text = "ACCURACY\n%.1f%%" % calculate_accuracy(hits, misses)
	var average_reaction_ms := calculate_average_reaction_ms(reaction_samples)
	reaction_label.text = "AVG REACTION\n%s" % ("--" if reaction_samples.is_empty() else "%d ms" % int(round(average_reaction_ms)))

	if session_finished:
		status_label.text = "Session complete"
	elif session_started:
		status_label.text = "Live fire" if selected_scenario != "tracking" else "Stay on target"
	else:
		status_label.text = "Starting in %.1f" % countdown_remaining

func _update_results_panel() -> void:
	results_score_label.text = "Score %d" % score
	results_stats_label.text = "Hits %d\nMisses %d\nAccuracy %.1f%%\nAverage Reaction %s" % [
		hits,
		misses,
		calculate_accuracy(hits, misses),
		"--" if reaction_samples.is_empty() else "%d ms" % int(round(calculate_average_reaction_ms(reaction_samples)))
	]
	leaderboard_status.text = "Submitting score..."

func _submission_status_text(submission) -> String:
	if submission == null:
		return "Unable to submit score."
	var prefix := "New personal best saved" if submission.personal_best else "Score submitted"
	return "%s · Position #%d" % [prefix, submission.position]

func _scenario_leaderboard_rows(scores: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry in scores:
		rows.append({
			"rank": entry.position,
			"name": entry.username,
			"score": entry.score,
			"accuracy": "%.1f%%" % entry.accuracy,
			"reaction": "--" if is_zero_approx(entry.avg_reaction_ms) else "%d ms" % int(round(entry.avg_reaction_ms))
		})
	return rows

func _can_apply_results_request(generation: int) -> bool:
	return is_inside_tree() and generation == results_request_generation

func _submit_results_and_load_leaderboard(generation: int) -> void:
	var accuracy := calculate_accuracy(hits, misses)
	var average_reaction_ms := calculate_average_reaction_ms(reaction_samples)
	var submission = await Global.server_bridge.submit_aim_score(
		selected_scenario,
		score,
		hits,
		misses,
		accuracy,
		int(round(average_reaction_ms))
	)
	if not _can_apply_results_request(generation):
		return

	var submission_status := _submission_status_text(submission)
	if submission == null:
		leaderboard_status.text = "%s Loading leaderboard..." % submission_status
	else:
		leaderboard_status.text = "%s · Loading leaderboard..." % submission_status

	var leaderboard = await Global.server_bridge.get_aim_scores(selected_scenario, 1)
	if not _can_apply_results_request(generation):
		return

	if leaderboard == null:
		show_leaderboard_error("%s Leaderboard unavailable." % submission_status)
		return

	if leaderboard.scores.is_empty():
		_clear_leaderboard_rows()
		leaderboard_status.text = "%s No leaderboard entries yet." % submission_status
		return

	show_leaderboard_rows(_scenario_leaderboard_rows(leaderboard.scores))
	if submission == null:
		leaderboard_status.text = "Unable to submit score. Showing latest leaderboard."
	else:
		leaderboard_status.text = submission_status

func _go_to_main_menu() -> void:
	results_request_generation += 1
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
