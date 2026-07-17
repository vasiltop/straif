extends RefCounted

static func should_enqueue(record_id: int, last_seen_id: int, enabled: bool) -> bool:
	return enabled and record_id > last_seen_id

static func should_display_response(
	enabled_at_request: bool,
	request_generation: int,
	current_generation: int,
	catch_up_at_request: bool
) -> bool:
	return (
		enabled_at_request
		and request_generation == current_generation
		and not catch_up_at_request
	)

static func completes_catch_up(
	enabled_at_request: bool,
	request_generation: int,
	current_generation: int,
	catch_up_at_request: bool,
	has_more: bool
) -> bool:
	return (
		enabled_at_request
		and request_generation == current_generation
		and catch_up_at_request
		and not has_more
	)

static func should_apply_bootstrap_response(last_seen_id: int) -> bool:
	return last_seen_id < 0

static func clear_if_disabled(messages: Array[String], enabled: bool) -> void:
	if not enabled:
		messages.clear()

static func format_message(record: Dictionary) -> String:
	return "WORLD RECORD! %s - %s (%s): %.3fs" % [
		record.username as String,
		record.map_name as String,
		record.mode as String,
		(record.time_ms as int) / 1000.0,
	]
