extends Node3D

@onready var start_zone = $Level/StartZone
@onready var end_zone = $Level/EndZone
@onready var timer_label = $Timer
@onready var audio_player = $Music

var track1 = preload("res://sound/track1.wav")

var timer = 0
var completed = false
var started = false

func _ready():
	start_zone.get_node("Area3D").body_exited.connect(player_started)
	end_zone.get_node("Area3D").body_entered.connect(player_finished)

func player_started(col):
	
	if !started:
		audio_player.stream = track1
		audio_player.play()
	started = true

func player_finished(col):
	completed = true
	
func _process(delta):
	if Input.is_action_just_pressed("jump"):
		player_started({})
		
	if not completed and started:
		timer += delta
		timer_label.text = str(snapped(timer, 0.01)) + " s"
