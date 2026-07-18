class_name HeartbeatState
extends RefCounted

enum Result {
	HEALTHY,
	MAINTENANCE,
	TRANSIENT_FAILURE,
	REQUEST_REJECTED,
}

const HEALTHY := Result.HEALTHY
const MAINTENANCE := Result.MAINTENANCE
const TRANSIENT_FAILURE := Result.TRANSIENT_FAILURE
const REQUEST_REJECTED := Result.REQUEST_REJECTED

var _active_request_id := 0
var _next_request_id := 0
var _degraded := false
var _failure_result := -1


func begin_request() -> int:
	if _active_request_id != 0:
		return 0

	_next_request_id += 1
	_active_request_id = _next_request_id
	return _active_request_id


func finish_request(request_id: int) -> bool:
	if request_id != _active_request_id:
		return false

	_active_request_id = 0
	return true


func mark_failure(result := Result.TRANSIENT_FAILURE) -> bool:
	if _degraded and result == _failure_result:
		return false

	_degraded = true
	_failure_result = result
	return true


func mark_success() -> bool:
	if not _degraded:
		return false

	_degraded = false
	_failure_result = -1
	return true


static func classify(has_response: bool, status: int, payload: Variant) -> int:
	if not has_response:
		return Result.TRANSIENT_FAILURE
	if status >= 400 and status < 500:
		return Result.REQUEST_REJECTED
	if status != 200:
		return Result.TRANSIENT_FAILURE
	if not payload is Dictionary:
		return Result.TRANSIENT_FAILURE

	var data: Variant = payload.get("data")
	if not data is Dictionary:
		return Result.TRANSIENT_FAILURE
	if data.get("maintenance") is bool and data.get("maintenance"):
		return Result.MAINTENANCE
	return Result.HEALTHY
