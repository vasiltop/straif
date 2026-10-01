extends Control

@onready var quit: Button = $Quit
@onready var play_offline: Button = $PlayOffline

func _ready() -> void:
	Global \
			.game_manager \
			.maintenance_changed \
			.connect(
			func() -> void:
				if not Global.game_manager.maintenance:
					get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")
	)

	quit.pressed.connect(get_tree().quit)
	play_offline.pressed.connect(_play_offline)

func _play_offline() -> void:
	Global.enable_offline_mode()
	get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")
