class_name Recorder extends Node 

const EYE_HEIGHT := 0.85
const HEADER := -1
const PlayerScene = preload("res://src/player/player.tscn")

var player_cam: Camera3D
var frames: Array[Frame]
var currently_playing: Array
var current_frame: int
var paused: bool = true
var controller: Player
var map: Map
var is_ghost: bool

class Frame:
	var position: Vector3
	var rot: Vector2
	var shoot_input: bool
	var interact_input: bool
	var weapon_index: int

func _init(player_cam: Camera3D, map: Map) -> void:
	self.player_cam = player_cam
	self.map = map

func _ready() -> void:
	var inst := PlayerScene.instantiate()
	
	add_child(inst)
	inst.visible = false
	var mesh := inst.get_node("ThirdPerson/Model/FullArmature/Skeleton3D/character") as MeshInstance3D
	mesh.set_surface_override_material(0, load("res://src/player/player_transparent.tres"))
	controller = inst

func add_frame(frame: Frame) -> void:
	frames.append(frame)

func clear() -> void:
	frames.clear()

func pause_playback() -> void:
	paused = true
	
func resume_playback() -> void:
	paused = false

func set_frame(value: int) -> void:
	if value >= currently_playing.size(): return
	
	var frame: Frame = currently_playing[value]
	
	controller.global_position = frame.position
	controller.camera._input_rotation.y = frame.rot.y
	controller.camera._input_rotation.x = frame.rot.x
	
	if is_ghost and controller.weapon_handler.weapon_scene:
		controller.weapon_handler.weapon_scene.get_parent().rotation.x = frame.rot.x
	
	if frame.shoot_input:
		controller.weapon_handler._try_shoot(true)

	var prev_frame: Frame = currently_playing[current_frame]
	#var last_frame: Frame = currently_playing[max(value - 1, 0)]
	
	var prev_position: Vector3 = prev_frame.position
	var current_position: Vector3 = frame.position
	
	prev_position.y = 0
	current_position.y = 0
	
	var diff := current_position - prev_position
	var dt := 1.0 / 60.0
	var speed := diff.length() / dt
	
	if is_ghost:
		controller.set_animation_blend(1.0 if speed >= 3.0 else 0.0)
	else:
		map.map_ui.set_speed(speed)
		map.map_ui.set_timer(current_frame * dt)
		
	if prev_frame.weapon_index != frame.weapon_index:
		controller.weapon_handler.set_weapon(Global.game_manager.get_weapon_from_index(frame.weapon_index), is_ghost)

	current_frame = value

func play_frames(header: int, frames: Array, is_ghost: bool) -> void:
	current_frame = 0
	controller.visible = true
	self.is_ghost = is_ghost
	controller.weapon_handler.set_weapon(null, is_ghost)
	
	if not is_ghost:
		controller.camera.make_current()
		controller.gun_camera.make_current()
		controller.weapon_handler.visible = true
		controller.third_person.visible = false
	else:
		controller.third_person.visible = true
		controller.weapon_handler.visible = false
	
	currently_playing = frames
	resume_playback()

func is_playing() -> bool:
	return current_frame < len(currently_playing)

func _physics_process(delta: float) -> void:
	if not paused and not is_playing():
		return
	
	if paused: return
	
	set_frame(current_frame + 1)

func to_hex() -> String:
	var bytes := to_bytes()
	return Marshalls.raw_to_base64(bytes)

func to_bytes() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_32(HEADER)
	buffer.put_u32(frames.size())

	for frame in frames:
		buffer.put_float(frame.position.x)
		buffer.put_float(frame.position.y)
		buffer.put_float(frame.position.z)
		buffer.put_float(frame.rot.x)
		buffer.put_float(frame.rot.y)
		
		var packed := 0

		if frame.shoot_input:
			packed |= 1 << 0
		if frame.interact_input:
			packed |= 1 << 1
		
		packed |= (frame.weapon_index & 0b00111111) << 2

		buffer.put_u8(packed)
	
	return buffer.data_array
		
func frames_from_bytes(data: PackedByteArray) -> Array:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	buffer.seek(0)
	var header := buffer.get_32()
	
	var frames: Array
	match header:
		-1:
			var size := buffer.get_u32()
			for i in size:
				var x := buffer.get_float()
				var y := buffer.get_float()
				var z := buffer.get_float()
				var rot_x := buffer.get_float()
				var rot_y := buffer.get_float()
				
				var packed := buffer.get_u8()

				var frame := Frame.new()
				frame.shoot_input = (packed & (1 << 0)) != 0
				frame.interact_input = (packed & (1 << 1)) != 0
				frame.weapon_index = (packed >> 2) & 0b00111111
				frame.position.x = x
				frame.position.y = y
				frame.position.z = z
				frame.rot.x = rot_x
				frame.rot.y = rot_y

				frames.append(frame)
	
	return frames

func get_version(data: PackedByteArray) -> int:
	var buffer := StreamPeerBuffer.new()
	
	buffer.data_array = data
	buffer.seek(0)
	var header := buffer.get_32()
	
	return header

func play_bytes(data: PackedByteArray, is_ghost := false) -> void:
	var version := get_version(data)
	var frames := frames_from_bytes(data)
	play_frames(version, frames, is_ghost)
