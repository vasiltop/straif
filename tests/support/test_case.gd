class_name TestCase
extends RefCounted

var failed := false

func check(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error(message)
	return condition

func check_equal(actual, expected, message: String) -> bool:
	var condition: bool = actual == expected
	if not condition:
		failed = true
		push_error("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
	return condition

func finish() -> int:
	return 1 if failed else 0
