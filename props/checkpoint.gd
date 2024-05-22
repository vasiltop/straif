extends Area3D


func _ready():
	body_entered.connect(checkpoint)

func checkpoint(col):
	if not col is CharacterBody3D: return
	
	get_parent().get_parent().set_checkpoint_pos($SpawnPoint.global_position)
