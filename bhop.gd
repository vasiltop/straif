extends Node3D

@onready var start_zone = $StartZone
@onready var end_zone = $EndZone
@onready var timer_label = $Timer

var timer = 0
var completed = true

func _ready():
	start_zone.body_exited.connect(player_in_start)
	end_zone.body_entered.connect(player_in_end)

func player_in_start(col):
	completed = false

func player_in_end(col):
	completed = true
	
func _process(delta):
	if not completed:
		timer += delta
		timer_label.text = str(timer) + " s"
