class_name BetterHTTPResponse

var _http: HTTPClient
var _scene: SceneTree
var _headers: Dictionary

func _internal_skip_body():
	while self._http.get_status() == HTTPClient.STATUS_BODY:
		var chunk = self._http.read_response_body_chunk()
		if chunk.size() == 0:
			await self._scene.process_frame

func body() -> PackedByteArray:
	var body = PackedByteArray()
	
	while self._http.get_status() == HTTPClient.STATUS_BODY:
		self._http.poll()

		var chunk = self._http.read_response_body_chunk()
		if chunk.size() == 0:
			await self._scene.process_frame
		else:
			body += chunk

	return body

func text() -> String:
	var body = await self.body()
	return body.get_string_from_utf8()

func json() -> Variant:
	var text = await self.text()
	var json = JSON.new()

	var err = json.parse(text)
	assert(err == OK)

	return json.data

func status() -> int:
	return self._http.get_response_code()

# iterates over the raw headers and returns
# a dictionary keyed by the header name in lower case
#
# cached after the first call
func headers() -> Dictionary:
	if not self._headers.is_empty():
		return self._headers

	var raw = self._http.get_response_headers()
	var headers = {}

	for header in raw:
		var colon = header.find(":")
		if colon == -1: continue

		headers[header.substr(0, colon).to_lower()] = header.substr(colon + 2)

	self._headers = headers
	self._headers.make_read_only()

	return headers

func header(name: String) -> Variant:
	return self.headers().get(name.to_lower())
