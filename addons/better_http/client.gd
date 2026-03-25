class_name BetterHTTPClient

extends RefCounted

var _base_url: BetterHTTPURL
var _default_headers: PackedStringArray
var _scene: SceneTree
var _max_redirects: int = 5

func _init(node: Node, base_url: BetterHTTPURL):
	self._scene = node.get_tree()
	self._base_url = base_url

func header(name: String, value: String) -> BetterHTTPClient:
	self._default_headers.push_back("%s: %s" % [name, value])
	return self

func max_redirects(max: int) -> BetterHTTPClient:
	self._max_redirects = max
	return self

func dispatch(method: HTTPClient.Method, path: String) -> BetterHTTPRequest:
	var req = BetterHTTPRequest.new()

	req._scene = self._scene
	req._method = method
	req._headers = self._default_headers.slice(0)
	req._max_redirects = self._max_redirects
	req._url = self._base_url.join(path)
	
	# needed for some sites that use a proxy of some sort
	req.header("host", self._base_url.http_host())
	req.header("connection", "keep-alive")

	return req

func http_get(path: String = "/") -> BetterHTTPRequest:
	return self.dispatch(HTTPClient.METHOD_GET, path)

func http_post(path: String = "/") -> BetterHTTPRequest:
	return self.dispatch(HTTPClient.METHOD_POST, path)

func http_put(path: String = "/") -> BetterHTTPRequest:
	return self.dispatch(HTTPClient.METHOD_PUT, path)

func http_patch(path: String = "/") -> BetterHTTPRequest:
	return self.dispatch(HTTPClient.METHOD_PATCH, path)

func http_delete(path: String = "/") -> BetterHTTPRequest:
	return self.dispatch(HTTPClient.METHOD_DELETE, path)
