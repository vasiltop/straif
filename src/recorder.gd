class_name Recorder extends Node 

const EYE_HEIGHT := 0.85
const GhostScene = preload("res://src/maps/ghost.tscn")

var player_cam: Camera3D
var frames: Array[FrameInfo]
var currently_playing: Array[FrameInfo]
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

func add_frame(position: Vector3, rot_y: float) -> void:
	frames.append(FrameInfo.new(position, rot_y))

func clear() -> void:
	frames.clear()

func pause_playback() -> void:
	paused = true
	
func resume_playback() -> void:
	paused = false

func play_frames(frames: Array[FrameInfo], is_ghost: bool) -> void:
	currently_playing = frames
	current_frame = 0
	
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
	
	var frame := currently_playing[current_frame]
	if not frame: return
	
	target.global_position = frame.position
	target.global_rotation.y = frame.rot_y
	
	if target is Camera3D:
		target.global_position.y += EYE_HEIGHT

	current_frame += 1

func to_bytes() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_32(frames.size())

	for frame in frames:
		buffer.put_float(frame.position.x)
		buffer.put_float(frame.position.y)
		buffer.put_float(frame.position.z)
		buffer.put_float(frame.rot_y)
	
	return buffer.data_array
		
func frames_from_bytes(data: PackedByteArray) -> Array[FrameInfo]:
	var frames: Array[FrameInfo] = []
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	buffer.seek(0)

	var count := buffer.get_32()

	for i in count:
		var x := buffer.get_float()
		var y := buffer.get_float()
		var z := buffer.get_float()
		var rot_y := buffer.get_float()
		frames.append(FrameInfo.new(Vector3(x, y, z), rot_y))
	
	return frames

func play_bytes(data: PackedByteArray, is_ghost := false) -> void:
	var frames := frames_from_bytes(data)
	play_frames(frames, is_ghost)

class FrameInfo:
	var position: Vector3
	var rot_y: float

	func _init(position: Vector3, rot_y: float) -> void:
		self.position = position
		self.rot_y = rot_y
