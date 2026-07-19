class_name LeaderboardRow extends PanelContainer

@onready var _rank: Label = $Margin/H/Rank
@onready var _name: Label = $Margin/H/Name
@onready var _value: Label = $Margin/H/Value

var _pending: Array = []

func set_data(rank: int, player_name: String, value: String) -> void:
	if not is_node_ready():
		_pending = [rank, player_name, value]
		return
	_rank.text = "%02d" % rank
	_name.text = player_name
	_value.text = value

func _ready() -> void:
	if not _pending.is_empty():
		set_data(_pending[0], _pending[1], _pending[2])
		_pending = []
