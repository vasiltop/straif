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

var _request_in_flight := false
var _degraded := false


func begin_request() -> bool:
	if _request_in_flight:
		return false

	_request_in_flight = true
	return true


func finish_request() -> void:
	_request_in_flight = false


func mark_failure() -> bool:
	if _degraded:
		return false

	_degraded = true
	return true


func mark_success() -> bool:
	if not _degraded:
		return false

	_degraded = false
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
