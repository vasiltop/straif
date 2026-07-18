extends SceneTree

const HEARTBEAT_STATE_PATH := "res://src/heartbeat_state.gd"

var failed := false


func _init() -> void:
	_run()


func _run() -> void:
	var HeartbeatState = load(HEARTBEAT_STATE_PATH)
	if HeartbeatState == null:
		_check(false, "Expected heartbeat state helper to load")
		quit(1)
		return

	var state = HeartbeatState.new()

	var first_request_id: int = state.begin_request()
	_check(first_request_id > 0, "begin_request should return a positive request token")
	_check(state.begin_request() == 0, "begin_request should reject an overlapping request")
	_check(not state.finish_request(first_request_id + 1), "finish_request should reject a wrong token")
	_check(state.begin_request() == 0, "a wrong token should not release the active request")
	_check(state.finish_request(first_request_id), "finish_request should accept the active token")
	var second_request_id: int = state.begin_request()
	_check(second_request_id > first_request_id, "request tokens should increase")
	_check(state.finish_request(second_request_id), "finish_request should accept the next active token")

	_check(
		state.mark_failure(HeartbeatState.TRANSIENT_FAILURE),
		"a transient failure should request a warning"
	)
	_check(
		not state.mark_failure(HeartbeatState.TRANSIENT_FAILURE),
		"repeated transient failures should not repeat the warning"
	)
	_check(
		state.mark_failure(HeartbeatState.REQUEST_REJECTED),
		"a rejected request after a transient failure should request a new warning"
	)
	_check(
		not state.mark_failure(HeartbeatState.REQUEST_REJECTED),
		"repeated rejected requests should not repeat the warning"
	)
	_check(state.mark_success(), "mark_success should report recovery after a failure streak")
	_check(not state.mark_success(), "mark_success should not repeat recovery while healthy")
	_check(
		state.mark_failure(HeartbeatState.TRANSIENT_FAILURE),
		"mark_success should reset failure warning state"
	)

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
		HeartbeatState.classify(true, 200, {"data": {}}) == HeartbeatState.HEALTHY,
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
