class_name Recorder extends Node 

const EYE_HEIGHT := 0.85
const GhostScene = preload("res://src/maps/ghost.tscn")
const HEADER := -1

var player_cam: Camera3D
var frames: Array[FrameInfoV2]
var currently_playing: Array
var currently_playing_version: int
var current_frame: int
var paused: bool
var camera := Camera3D.new()
var ghost: Node3D
var target: Node3D = null

func _init(player_cam: Camera3D) -> void:
	self.player_cam = player_cam

func _ready() -> void:
	var inst := GhostScene.instantiate()
	ghost = inst
	ghost.visible = false
	
	add_child(camera)
	add_child(inst)

func add_frame(frame: FrameInfoV2) -> void:
	frames.append(frame)

func clear() -> void:
	frames.clear()

func pause_playback() -> void:
	paused = true
	
func resume_playback() -> void:
	paused = false

func play_frames(header: int, frames: Array, is_ghost: bool) -> void:
	currently_playing = frames
	current_frame = 0
	currently_playing_version = header
	
	if is_ghost:
		target = ghost
		ghost.visible = true
	else:
		target = camera
	
	if not is_ghost:
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func is_playing() -> bool:
	return current_frame < len(currently_playing)

func _physics_process(_delta: float) -> void:
	if not is_playing(): return
	if paused: return
	
	var frame: Variant = currently_playing[current_frame]
	if not frame: return
	
	target.global_position = frame.position
	target.global_rotation.y = frame.rot_y
	
	if target is Camera3D:
		target.global_position.y += EYE_HEIGHT
		
		if currently_playing_version == -1:
			target.global_rotation.x = frame.rot_x

	current_frame += 1

func to_bytes() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_32(HEADER)
	buffer.put_32(frames.size())

	for frame in frames:
		buffer.put_float(frame.position.x)
		buffer.put_float(frame.position.y)
		buffer.put_float(frame.position.z)
		buffer.put_float(frame.rot_y)
		buffer.put_float(frame.rot_x)
	
	return buffer.data_array
		
func frames_from_bytes(data: PackedByteArray) -> Array:
	var frames: Array = []
	var buffer := StreamPeerBuffer.new()
	
	buffer.data_array = data
	buffer.seek(0)
	var header := buffer.get_32()
	
	match header:
		-1:
			var count := buffer.get_32()
			for i in count:
				var x := buffer.get_float()
				var y := buffer.get_float()
				var z := buffer.get_float()
				var rot_y := buffer.get_float()
				var rot_x := buffer.get_float()
				frames.append(FrameInfoV2.new(Vector3(x, y, z), rot_y, rot_x))
		_:
			buffer.seek(0)
			var count := buffer.get_32()

			for i in count:
				var x := buffer.get_float()
				var y := buffer.get_float()
				var z := buffer.get_float()
				var rot_y := buffer.get_float()
				frames.append(FrameInfo.new(Vector3(x, y, z), rot_y))

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

class FrameInfo:
	var position: Vector3
	var rot_y: float

	func _init(position: Vector3, rot_y: float) -> void:
		self.position = position
		self.rot_y = rot_y

class FrameInfoV2:
	var position: Vector3
	var rot_y: float
	var rot_x: float

	func _init(position: Vector3, rot_y: float, rot_x: float) -> void:
		self.position = position
		self.rot_y = rot_y
		self.rot_x = rot_x
