extends SceneTree

const WorldRecordAnnouncement = preload("res://src/world_record_announcement.gd")


func _init() -> void:
	var record := {
		"username": "Alice",
		"map_name": "Taurus",
		"mode": "target",
		"time_ms": 62345,
	}
	var actual: String = WorldRecordAnnouncement.format_message(record)
	var expected := "WORLD RECORD! Alice - Taurus (target): 62.345s"

	if actual != expected:
		push_error("Expected '%s', got '%s'." % [expected, actual])
		quit(1)
		return

	var seen_ids: Dictionary[String, bool] = {}
	if not WorldRecordAnnouncement.consume_unseen("record-1", seen_ids, true):
		push_error("Expected a new record to be queued when announcements are enabled.")
		quit(1)
		return

	if WorldRecordAnnouncement.consume_unseen("record-1", seen_ids, true):
		push_error("Expected an already-seen record to be suppressed.")
		quit(1)
		return

	if WorldRecordAnnouncement.consume_unseen("record-2", seen_ids, false):
		push_error("Expected disabled announcements to suppress a new record.")
		quit(1)
		return

	if not seen_ids.has("record-2"):
		push_error("Expected disabled announcements to still be marked as seen.")
		quit(1)
		return

	var queued_messages: Array[String] = ["old record"]
	WorldRecordAnnouncement.clear_if_disabled(queued_messages, false)
	if not queued_messages.is_empty():
		push_error("Expected disabling announcements to clear queued records immediately.")
		quit(1)
		return

	quit()
