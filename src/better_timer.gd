class_name BetterTimer extends RefCounted

var _on_timeout: Callable
var _time_secs: float
var _timer: Timer

func _init(node: Node, time_secs: float, on_timeout: Callable) -> void:
	var timer := Timer.new()
	node.add_child(timer)
	
	self._timer = timer
	self._time_secs = time_secs
	self._on_timeout = on_timeout

func _call_and_reset() -> void:
	self._timer.start(self._time_secs)
	_on_timeout.call()

func start() -> void:
	_call_and_reset()
	self._timer.timeout.connect(_call_and_reset)
