extends SceneTree

const HeartbeatState = preload("res://src/heartbeat_state.gd")

var failed := false


func _init() -> void:
	var state = HeartbeatState.new()

	_check(state.begin_request(), "begin_request should accept the first request")
	_check(not state.begin_request(), "begin_request should reject an overlapping request")
	state.finish_request()
	_check(state.begin_request(), "begin_request should accept a request after finish_request")
	state.finish_request()

	_check(state.mark_failure(), "mark_failure should request a warning for a new failure streak")
	_check(not state.mark_failure(), "mark_failure should not repeat a warning during a failure streak")
	_check(state.mark_success(), "mark_success should report recovery after a failure streak")
	_check(not state.mark_success(), "mark_success should not repeat recovery while healthy")
	_check(state.mark_failure(), "mark_failure should request a warning for the next failure streak")

	_check(
		HeartbeatState.classify(false, 0, null) == HeartbeatState.TRANSIENT_FAILURE,
		"no response should be a transient failure"
	)
	_check(
		HeartbeatState.classify(true, 503, {}) == HeartbeatState.TRANSIENT_FAILURE,
		"HTTP 503 should be a transient failure"
	)
	_check(
		HeartbeatState.classify(true, 401, {}) == HeartbeatState.REQUEST_REJECTED,
		"HTTP 401 should be request rejected"
	)
	_check(
		HeartbeatState.classify(true, 200, {"data": {"maintenance": false}}) == HeartbeatState.HEALTHY,
		"valid HTTP 200 data without maintenance should be healthy"
	)
	_check(
		HeartbeatState.classify(true, 200, {"data": {"maintenance": true}}) == HeartbeatState.MAINTENANCE,
		"valid HTTP 200 data with maintenance should require maintenance"
	)
	_check(
		HeartbeatState.classify(true, 200, {}) == HeartbeatState.TRANSIENT_FAILURE,
		"malformed HTTP 200 payload should be a transient failure"
	)

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
