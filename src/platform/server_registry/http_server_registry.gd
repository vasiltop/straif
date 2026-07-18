class_name HttpServerRegistry
extends ServerRegistry

var _bridge: Variant


func _init(server_bridge: Variant) -> void:
	_bridge = server_bridge


func publish(snapshot: Dictionary) -> Error:
	if _bridge == null or _bridge.client == null:
		return ERR_UNAVAILABLE
	var response: Variant = await _bridge.client.http_post("/browser").json(snapshot).send()
	if response == null:
		return ERR_CANT_CONNECT
	if response.status() != 200:
		return ERR_QUERY_FAILED
	return OK
