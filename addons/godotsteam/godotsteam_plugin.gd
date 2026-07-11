@tool
class_name GodotSteamPlugin
extends EditorPlugin

const EDITOR_PANEL = preload("uid://cyniebd6yahu5")

static var dock_frame

var link_changelog: String = "[url=https://godotsteam.com/changelog/gdextension/]changelog[/url]"
var link_website: String = "[url=https://godotsteam.com]website[/url]"
var steamworks_dock: Control


## Used specifically to add/remove additional dock content
static func get_dock_frame() -> Control:
	return dock_frame


func _enable_plugin() -> void:
	print("GodotSteam GDExtension updater functionality enabled")


func _disable_plugin() -> void:
	print("GodotSteam GDEXtension updater functionality disabled")


func _enter_tree() -> void:
	_check_outdated_api()
	print_rich("GodotSteam v%s | %s | %s" % [Steam.get_godotsteam_version(), link_website, link_changelog])
	add_project_settings()
	add_steamworks_dock()


func _exit_tree() -> void:
	remove_steamworks_dock()


func _make_visible(visible) -> void:
	if steamworks_dock:
		steamworks_dock.set_visible(visible)


#region Add and remove things
func add_project_settings() -> void:
	# Used for the Updater looking for redist files and SteamCMD
	if not ProjectSettings.has_setting("steam/updates/godotsteam/check_for_updates"):
		ProjectSettings.set_setting("steam/updates/godotsteam/check_for_updates", true)
	ProjectSettings.add_property_info({
		"name": "steam/updates/godotsteam/check_for_updates",
		"type": TYPE_BOOL
	})
	ProjectSettings.set_initial_value("steam/updates/godotsteam/check_for_updates", true)
	ProjectSettings.set_as_basic("steam/updates/godotsteam/check_for_updates", true)
	# Which channel of updates to pull from
	# Sponsors repo should require the user to have access to that repository already
	# In theory, they can connect via SSH?
	if not ProjectSettings.has_setting("steam/updates/godotsteam/update_channel"):
		ProjectSettings.set_setting("steam/updates/godotsteam/update_channel", 0)
	ProjectSettings.add_property_info({
		"name": "steam/updates/godotsteam/update_channel",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Community, Sponsors"
	})
	ProjectSettings.set_initial_value("steam/updates/godotsteam/update_channel", 0)
	ProjectSettings.set_as_basic("steam/updates/godotsteam/update_channel", true)


func add_steamworks_dock() -> void:
	steamworks_dock = EDITOR_PANEL.instantiate()
	# This will be used when 4.4.x is deprecated
	#add_control_to_dock(DockSlot.DOCK_SLOT_BOTTOM, steamworks_dock)
	# This is deprecated as of 4.6; when it is removed then 4.4.x will be deprecated for GodotSteam
	add_control_to_bottom_panel(steamworks_dock, "Steamworks")
	dock_frame = steamworks_dock


func remove_steamworks_dock() -> void:
	# This will be used when 4.4.x is deprecated
	#remove_control_from_docks(steamworks_dock)
	# This is deprecated as of 4.6; when it is removed then 4.4.x will be deprecated for GodotSteam
	remove_control_from_bottom_panel(steamworks_dock)
	# This may be causing crashes for some people and is unnecessary with the call above
	# steamworks_dock.queue_free()
	steamworks_dock = null
	dock_frame = null
#endregion


#region SDK version updating
func _check_outdated_api() -> void:
	if OS.get_name() == "Windows":
		print("Checking for Steam API mismatch")
		# We will check both unless there is a better way to check for 64-bits
		_check_steam_api("steam_api64.dll", "win64")
		_check_steam_api("steam_api.dll", "win32")


func _check_steam_api(dll_file: String, dll_location: String) -> void:
	var godot_sdk_path: String = "%s/%s" % [OS.get_executable_path().get_base_dir(), dll_file]
	var godotsteam_dir: String = ProjectSettings.globalize_path("res://addons/godotsteam")
	var godotsteam_sdk_path: String = "%s/%s/%s" % [godotsteam_dir, dll_location, dll_file]

	if FileAccess.file_exists(godot_sdk_path):
		if _md5_hashes_match(godot_sdk_path, godotsteam_sdk_path):
			return
		print("Steam API different between Godot and GodotSteam, copying over GodotSteam version")
		if not DirAccess.copy_absolute(godotsteam_sdk_path, godot_sdk_path) == OK:
			printerr("Failed to overwrite Steam API for Godot, you may need to manually update it")
			return
		if not _md5_hashes_match(godot_sdk_path, godotsteam_sdk_path):
			printerr("Steam API files still mismatch, you may need to manually update it")
			return
		print("Steam API file for Godot updated")


func _md5_hashes_match(godot_sdk: String, godotsteam_sdk: String) -> bool:
	var godot_sdk_md5: String = FileAccess.get_md5(godot_sdk)
	var godotsteam_sdk_md5: String = FileAccess.get_md5(godotsteam_sdk)

	if godot_sdk_md5 == godotsteam_sdk_md5:
		return true
	return false
#endregion
