extends RefCounted

static func consume_unseen(record_id: String, seen_ids: Dictionary, enabled: bool) -> bool:
	if seen_ids.has(record_id):
		return false
	seen_ids[record_id] = true
	return enabled

static func clear_if_disabled(messages: Array[String], enabled: bool) -> void:
	if not enabled:
		messages.clear()

static func format_message(record: Dictionary) -> String:
	return (
		"WORLD RECORD! %s - %s (%s): %.3fs" % [
			record.username as String,
			record.map_name as String,
			record.mode as String,
			(record.time_ms as int) / 1000.0,
		]
	)
