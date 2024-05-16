extends Button

var id = 0

func _ready():
	pressed.connect(on_click)

func set_label(name: String):
	$Label.text = name

func set_id(_id: int):
	id = _id

func on_click():
	SteamClient.join_lobby(id)
