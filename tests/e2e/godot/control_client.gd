extends Node

const _AK47 := preload("res://src/player/weapon/resources/ak47.tres")
const _BLOOD_SCENE := "res://src/player/weapon/blood.tscn"
const _TRACER_SCENE := "res://src/player/weapon/bullet_tracer.tscn"
const _EYE_OFFSET := Vector3(0.0, 0.85, 0.0)
const _TORSO_BONE := "Physical Bone middle"

var _instance := ""
var _port := 0
var _stream: StreamPeerTCP = null
var _hello_sent := false
var _rx := ""
var _pending_quit := false
var _aim_target_pid := 0
var _last_bullet := { }
var _effect_counts := { "blood": 0, "tracer": 0 }

func _ready() -> void:
	var options = Global.context.options
	_instance = String(options.e2e_instance)
	_port = int(options.e2e_control_port)
	_stream = StreamPeerTCP.new()
	_stream.connect_to_host("127.0.0.1", _port)
	get_tree().node_added.connect(_on_node_added)
	set_process(true)

func _on_node_added(node: Node) -> void:
	var path := node.scene_file_path
	if path == _BLOOD_SCENE:
		_effect_counts.blood += 1
	elif path == _TRACER_SCENE:
		_effect_counts.tracer += 1

func _process(_delta: float) -> void:
	if _stream == null:
		return
	_stream.poll()
	if _stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if not _hello_sent:
			_send({ "hello": { "instance": _instance } })
			_hello_sent = true
		_drain()
	if _pending_quit:
		get_tree().quit(0)

func _drain() -> void:
	var available := _stream.get_available_bytes()
	if available > 0:
		var chunk := _stream.get_data(available)
		if chunk[0] == OK:
			_rx += (chunk[1] as PackedByteArray).get_string_from_utf8()
	while true:
		var newline := _rx.find("\n")
		if newline < 0:
			break
		var line := _rx.substr(0, newline).strip_edges()
		_rx = _rx.substr(newline + 1)
		if not line.is_empty():
			_handle_line(line)

func _handle_line(line: String) -> void:
	var parsed = JSON.parse_string(line)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var message: Dictionary = parsed
	if not message.has("id"):
		return
	var request_id := int(message["id"])
	var command = message.get("command")
	if typeof(command) != TYPE_STRING:
		_respond(request_id, _error("command must be a string"))
		return
	var args = message.get("args", { })
	if typeof(args) != TYPE_DICTIONARY:
		_respond(request_id, _error("args must be an object"))
		return
	_respond(request_id, _dispatch(command, args))

func _dispatch(command: String, args: Dictionary) -> Dictionary:
	match command:
		"snapshot":
			return _ok(_snapshot())
		"load_fixture":
			return _load_fixture(args)
		"teleport":
			return _teleport(args)
		"equip_ak47":
			return _equip_ak47()
		"aim":
			return _aim(args)
		"fire":
			return _fire()
		"reload":
			return _reload()
		"shutdown":
			return _shutdown()
	return _error("unknown command %s" % command)

func _snapshot() -> Dictionary:
	var deathmatch := _deathmatch()
	var players := []
	for player in _player_nodes(deathmatch):
		var player_state := {
			"pid": int(player.pid),
			"name": String(player.player_name()),
			"health": float(player.health),
			"dead": bool(player.is_dead),
			"position": _vec(player.global_position),
		}
		players.append(player_state)
	return {
		"fixture": _fixture_info(deathmatch),
		"players": players,
		"weapon": _weapon_info(deathmatch),
		"effects": _effect_counts.duplicate(),
		"killfeed": _killfeed(deathmatch),
	}

func _load_fixture(args: Dictionary) -> Dictionary:
	if _instance != "server":
		return _error("load_fixture is server-only")
	var path := String(args.get("path", ""))
	if path.is_empty():
		return _error("load_fixture requires a path")
	if not ResourceLoader.exists(path):
		return _error("fixture not found: %s" % path)
	var deathmatch := _deathmatch()
	if deathmatch == null:
		return _error("deathmatch scene not ready")
	deathmatch.change_map.rpc(path)
	var loaded := deathmatch.loaded_map != null and deathmatch.loaded_map.scene_file_path == path
	return _ok({ "loaded": loaded, "path": path })

func _teleport(args: Dictionary) -> Dictionary:
	var deathmatch := _deathmatch()
	var player := _local_player(deathmatch)
	if player == null:
		return _error("no local player to teleport")
	var coords = args.get("position", [])
	if typeof(coords) != TYPE_ARRAY or coords.size() != 3:
		return _error("teleport requires position [x, y, z]")
	var target := Vector3(coords[0], coords[1], coords[2])
	player.velocity = Vector3.ZERO
	player.global_position = target
	if Global.mp():
		player._update_state.rpc(target, player.global_rotation.y, player.camera._input_rotation.x, 0.0)
	return _ok({ "position": _vec(player.global_position) })

func _equip_ak47() -> Dictionary:
	var deathmatch := _deathmatch()
	var player := _local_player(deathmatch)
	if player == null:
		return _error("no local player to equip")
	player.weapon_handler.set_weapon(_AK47, false)
	return _ok({ "weapon": String(_AK47.name) })

func _aim(args: Dictionary) -> Dictionary:
	var deathmatch := _deathmatch()
	var shooter := _local_player(deathmatch)
	if shooter == null:
		return _error("no local player to aim")
	var target_pid := int(args.get("target", 0))
	var target := _find_player(deathmatch, target_pid)
	if target == null:
		return _error("aim target %d not found" % target_pid)
	var point = _target_point(target)
	if point == null:
		return _error("aim target %d has no body part" % target_pid)
	_aim_target_pid = target_pid
	_apply_aim(shooter, point)
	return _ok({ })

func _fire() -> Dictionary:
	var deathmatch := _deathmatch()
	var shooter := _local_player(deathmatch)
	if shooter == null:
		return _error("no local player to fire")
	var target := _find_player(deathmatch, _aim_target_pid)
	if target == null:
		return _error("no aim target selected")
	var point = _target_point(target)
	if point == null:
		return _error("aim target has no body part")
	_apply_aim(shooter, point)
	var handler := shooter.weapon_handler
	if not _weapon_ready(handler):
		return _ok({ "fired": false, "reason": "weapon_not_ready" })
	var before := int(handler.mag_ammo)
	_last_bullet = { }
	if not handler.bullet_fired.is_connected(_on_bullet_fired):
		handler.bullet_fired.connect(_on_bullet_fired)
	handler._try_shoot()
	var after := int(handler.mag_ammo)
	var collider = _last_bullet.get("collider")
	return _ok(
			{
				"fired": true,
				"ammo_before": before,
				"ammo_after": after,
				"decremented": after < before,
				"hit_pid": _collider_pid(collider),
				"hit_is_body_part": collider is BodyPart,
			}
	)

func _reload() -> Dictionary:
	var deathmatch := _deathmatch()
	var player := _local_player(deathmatch)
	if player == null:
		return _error("no local player to reload")
	var handler := player.weapon_handler
	if handler.current_weapon == null:
		return _error("no weapon to reload")
	handler.reload()
	return _ok({ "mag": int(handler.mag_ammo), "max": int(handler.max_mag_ammo) })

func _shutdown() -> Dictionary:
	_pending_quit = true
	return _ok({ "shutdown": true })

func _apply_aim(shooter, point: Vector3) -> void:
	var eye: Vector3 = shooter.global_position + _EYE_OFFSET
	var direction := (point - eye).normalized()
	var camera = shooter.camera
	camera._input_rotation.y = atan2(-direction.x, -direction.z)
	camera._input_rotation.x = clampf(asin(clampf(direction.y, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(85.0))
	camera._mouse_input = Vector2.ZERO
	shooter.weapon_handler.current_recoil = Vector2.ZERO

func _collider_pid(collider) -> int:
	if collider is BodyPart:
		var owner = collider.owned_by
		if owner != null:
			return int(owner.pid)
	return -1

func _on_bullet_fired(collider, hit_position: Vector3) -> void:
	_last_bullet = { "collider": collider, "position": hit_position }

func _target_point(target):
	var parts := _body_parts(target)
	if parts.is_empty():
		return null
	for part in parts:
		if part.name == _TORSO_BONE:
			return _part_point(part)
	return _part_point(parts[0])

func _body_parts(target) -> Array:
	var result := []
	var simulator = target.bone_simulator
	if simulator == null:
		return result
	for child in simulator.get_children():
		if child is BodyPart:
			result.append(child)
	return result

func _part_point(part) -> Vector3:
	var shape = part.get_node_or_null("CollisionShape3D")
	if shape != null:
		return shape.global_position
	return part.global_position

func _weapon_ready(handler) -> bool:
	if handler.current_weapon == null:
		return false
	if handler.weapon_scene == null:
		return false
	if not handler.can_shoot(false):
		return false
	var anim = handler.weapon_scene.get_node_or_null("AnimationPlayer")
	if anim == null:
		return false
	if anim.current_animation == "equip":
		return false
	return true

func _deathmatch() -> Deathmatch:
	var scene := get_tree().current_scene
	if scene is Deathmatch:
		return scene
	return null

func _player_nodes(deathmatch) -> Array:
	if deathmatch == null or deathmatch.players == null:
		return []
	return deathmatch.players.get_children()

func _find_player(deathmatch, pid: int) -> Player:
	for player in _player_nodes(deathmatch):
		if int(player.pid) == pid:
			return player
	return null

func _local_player(deathmatch) -> Player:
	return _find_player(deathmatch, Global.id())

func _fixture_info(deathmatch) -> Dictionary:
	if deathmatch == null or deathmatch.loaded_map == null:
		return { "loaded": false, "path": "", "name": "" }
	var map = deathmatch.loaded_map
	return { "loaded": true, "path": String(map.scene_file_path), "name": String(map.name) }

func _weapon_info(deathmatch):
	var player := _local_player(deathmatch)
	if player == null:
		return null
	var handler := player.weapon_handler
	if handler == null or handler.current_weapon == null:
		return null
	return {
		"name": String(handler.current_weapon.name),
		"mag": int(handler.mag_ammo),
		"max": int(handler.max_mag_ammo),
		"ready": _weapon_ready(handler),
	}

func _killfeed(deathmatch) -> Array:
	if deathmatch == null or deathmatch.dm_ui == null or deathmatch.dm_ui.killfeed == null:
		return []
	var texts := []
	for child in deathmatch.dm_ui.killfeed.get_children():
		if child is Label:
			texts.append(String(child.text))
	return texts

func _vec(value: Vector3) -> Array:
	return [float(value.x), float(value.y), float(value.z)]

func _ok(result: Dictionary) -> Dictionary:
	return { "ok": true, "result": result }

func _error(message: String) -> Dictionary:
	return { "ok": false, "error": message }

func _respond(request_id: int, outcome: Dictionary) -> void:
	var frame := { "id": request_id, "ok": outcome.get("ok", false) }
	if outcome.has("result"):
		frame["result"] = outcome["result"]
	if outcome.has("error"):
		frame["error"] = outcome["error"]
	_send(frame)

func _send(frame: Dictionary) -> void:
	if _stream == null:
		return
	var text := JSON.stringify(frame) + "\n"
	_stream.put_data(text.to_utf8_buffer())
