class_name DmUi extends CanvasLayer

@export var killfeed: Container
@export var weapon_buttons_container: Container
@export var weapon_select: Container
@export var ammo_label: Label
@export var health_label: Label
@export var time_left_label: Label

const MAX_KILLFEED_LENGTH := 5
const KILLFEED_FONT_SIZE := 15
const FEED_TTL := 5.0
const TIME_PER_MAP := 180.0

var time_since_last_feed_update := 0.0
var game_time := TIME_PER_MAP
var game_timer := BetterTimer.new(self, 1.0, 
	func() -> void:
		if Global.is_sv():
			update_time_label.rpc(game_time)
)

@rpc("call_local", "authority", "unreliable")
func update_time_label(value: float) -> void:
	time_left_label.text = "Time Left: %ds" % value

func _ready() -> void:
	game_timer.start()
	weapon_select.visible = false
	
	for weapon in Global.game_manager.weapons:
		if weapon == null: continue
		
		var btn := Button.new()
		weapon_buttons_container.add_child(btn)
		btn.text = weapon.name
		btn.focus_mode = Control.FOCUS_NONE
		var index := Global.game_manager.get_weapon_index(weapon)
		
		btn.pressed.connect(
			func() -> void:
				for player in get_parent().get_players():
					send_weapon_update_to(index, player.pid)
				
				send_weapon_update_to(index, 1)
		)
		
func send_weapon_update_to(weapon_index: int, to: int) -> void:
	get_parent().get_player(Global.id()).weapon_handler.set_weapon_to_index.rpc_id(to, weapon_index, Global.id() != to)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("leaderboard"):
		weapon_select.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if Input.is_action_just_released("leaderboard"):
		weapon_select.visible = false
		
		if not get_parent().get_player(Global.id()).is_paused():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	time_since_last_feed_update += delta
	
	if time_since_last_feed_update >= FEED_TTL:
		killfeed.visible = false
		for child in killfeed.get_children():
			child.queue_free()
	
	if Global.is_sv():
		game_time -= delta
		
		if game_time <= 0:
			get_parent().new_map()
			game_time = TIME_PER_MAP

@rpc("authority", "call_local", "reliable")
func log_kill(killer_name: String, player_name: String, weapon_name: String) -> void:
	feed_log("Player %s has eliminated %s with weapon: %s!" % [killer_name, player_name, weapon_name])

@rpc("authority", "call_local", "reliable")
func log_player_event(player_name: String, joined: bool) -> void:
	feed_log("Player %s has %s the lobby." % [player_name, "joined" if joined else "left"])

func feed_log(value: String) -> void:
	var count := killfeed.get_child_count()
	if count >= MAX_KILLFEED_LENGTH:
		killfeed.get_child(0).queue_free()
		
	killfeed.visible = true
	time_since_last_feed_update = 0.0
	var label := Label.new()
	label.text = value
	killfeed.add_child(label)
	label.add_theme_font_size_override("font_size", KILLFEED_FONT_SIZE)
	
func on_shot(mag_ammo: int, reserve_ammo: int) -> void:
	ammo_label.text = "Ammo: %d / %d" % [mag_ammo, reserve_ammo]

func on_damaged(health: float) -> void:
	health_label.text = "Health: %d" % [health]
