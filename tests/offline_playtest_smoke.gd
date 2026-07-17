extends SceneTree

const GLOBAL_SCRIPT_PATH := "res://src/global.gd"
const GAME_MANAGER_SCRIPT_PATH := "res://src/game_manager.gd"

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var global_script_file := FileAccess.open(GLOBAL_SCRIPT_PATH, FileAccess.READ)
	_check(global_script_file != null, "Expected %s to open" % GLOBAL_SCRIPT_PATH)
	if global_script_file != null:
		var global_source := global_script_file.get_as_text()
		_check(global_source.contains("--offline-playtest"), "Global should reference the exact --offline-playtest flag")
		_check(global_source.contains("OS.get_cmdline_user_args()"), "Global should read user args when deciding offline playtest mode")
	
	var global_node := root.get_node_or_null("Global")
	_check(global_node != null, "Global autoload should exist during the smoke test")
	if global_node != null:
		_check(global_node.has_method("is_offline_playtest_mode"), "Global should expose an offline playtest helper")
		if global_node.has_method("is_offline_playtest_mode"):
			_check(not global_node.is_offline_playtest_mode(PackedStringArray([])), "Offline playtest helper should default to false")
			_check(global_node.is_offline_playtest_mode(PackedStringArray(["--offline-playtest"])), "Offline playtest helper should enable the exact flag")
			_check(not global_node.is_offline_playtest_mode(PackedStringArray(["--offline-playtestx"])), "Offline playtest helper should ignore partial flag matches")
	
	var game_manager_script_file := FileAccess.open(GAME_MANAGER_SCRIPT_PATH, FileAccess.READ)
	_check(game_manager_script_file != null, "Expected %s to open" % GAME_MANAGER_SCRIPT_PATH)
	if game_manager_script_file != null:
		var game_manager_source := game_manager_script_file.get_as_text()
		_check(
			game_manager_source.contains("func _init(is_server: bool, request_auth_ticket: bool = true) -> void:"),
			"GameManager should accept a typed request_auth_ticket constructor flag"
		)
	
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
