class_name RecordingServerRegistry
extends ServerRegistry

var _snapshots: Array[Dictionary] = []

func publish(snapshot: Dictionary) -> Error:
	_snapshots.append(snapshot.duplicate(true))
	return OK

func snapshots() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for snapshot in _snapshots:
		copy.append(snapshot.duplicate(true))
	return copy
