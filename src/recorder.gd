class_name Recorder extends Node 

const EYE_HEIGHT := 0.85

var player_cam: Camera3D
var frames: Array[FrameInfo]
var currently_playing: Array[FrameInfo]
var current_frame: int
var paused := true
var camera := Camera3D.new()


func _ready() -> void:
	add_child(camera)

func add_frame(position: Vector3, rot_y: float) -> void:
	frames.append(FrameInfo.new(position, rot_y))

func clear() -> void:
	frames.clear()

func play_frames(frames: Array[FrameInfo]) -> void:
	currently_playing = frames
	current_frame = 0

	camera.make_current()
	paused = false

func _physics_process(_delta: float) -> void:
	if paused: return
	
	var frame := currently_playing[current_frame]
	if not frame: return
	
	camera.global_position = frame.position
	camera.global_position.y += EYE_HEIGHT
	camera.global_rotation.y = frame.rot_y

	current_frame += 1

	if current_frame >= len(currently_playing):
		paused = true
		camera.current = false

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

func play_bytes(data: PackedByteArray) -> void:
	var frames := frames_from_bytes(data)
	play_frames(frames)

class FrameInfo:
	var position: Vector3
	var rot_y: float

	func _init(position: Vector3, rot_y: float) -> void:
		self.position = position
		self.rot_y = rot_y
