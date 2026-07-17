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
	
	if not WorldRecordAnnouncement.should_enqueue(6, 5, true):
		push_error("Expected a new record to be queued when announcements are enabled.")
		quit(1)
		return
	
	if WorldRecordAnnouncement.should_enqueue(6, 5, false):
		push_error("Expected disabled announcements to suppress a new record.")
		quit(1)
		return
	
	if WorldRecordAnnouncement.should_enqueue(5, 5, true):
		push_error("Expected an already-seen record to be suppressed.")
		quit(1)
		return
	
	if not WorldRecordAnnouncement.should_display_response(true, 3, 3, false):
		push_error("Expected a current enabled response to display records.")
		quit(1)
		return
	
	if WorldRecordAnnouncement.should_display_response(true, 2, 3, false):
		push_error("Expected a stale settings-generation response to be suppressed.")
		quit(1)
		return
	
	if WorldRecordAnnouncement.should_display_response(true, 3, 3, true):
		push_error("Expected the first response after re-enabling to catch up silently.")
		quit(1)
		return
	
	if not WorldRecordAnnouncement.completes_catch_up(true, 3, 3, true, false):
		push_error("Expected a current enabled response to complete catch-up.")
		quit(1)
		return
	
	if WorldRecordAnnouncement.completes_catch_up(true, 3, 3, true, true):
		push_error("Expected catch-up to continue while more pages remain.")
		quit(1)
		return
	
	if not WorldRecordAnnouncement.should_apply_bootstrap_response(-1):
		push_error("Expected the first successful bootstrap response to initialize the cursor.")
		quit(1)
		return
	
	if WorldRecordAnnouncement.should_apply_bootstrap_response(5):
		push_error("Expected a late bootstrap response to leave the initialized cursor unchanged.")
		quit(1)
		return
	
	var queued_messages: Array[String] = ["old record"]
	WorldRecordAnnouncement.clear_if_disabled(queued_messages, false)
	if not queued_messages.is_empty():
		push_error("Expected disabling announcements to clear queued records immediately.")
		quit(1)
		return
	
	quit()
