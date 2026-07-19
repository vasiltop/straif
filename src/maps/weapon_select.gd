class_name WeaponSelect extends PanelContainer

signal weapon_chosen(index: int)

@onready var weapon_buttons_container: VBoxContainer = $MarginContainer/VBoxContainer/WeaponButtons

func _ready() -> void:
	visible = false

	for weapon in Global.game_manager.weapons:
		if weapon == null:
			continue

		var index := Global.game_manager.get_weapon_index(weapon)
		if index <= 0:
			continue

		var btn := Button.new()
		weapon_buttons_container.add_child(btn)
		btn.text = weapon.name
		btn.theme_type_variation = &"GhostButton"
		btn.custom_minimum_size = Vector2(0.0, 40.0)
		btn.focus_mode = Control.FOCUS_NONE

		btn.pressed.connect(func() -> void: weapon_chosen.emit(index))
