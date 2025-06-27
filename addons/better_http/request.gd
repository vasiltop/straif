class_name BetterHTTPRequest

var _url: BetterHTTPURL
var _max_redirects: int

var _method: HTTPClient.Method
var _body: PackedByteArray
var _headers: PackedStringArray

var _scene: SceneTree

func header(name: String, value: String) -> BetterHTTPRequest:
	self._headers.push_back("%s: %s" % [name, value])
	return self

func max_redirects(max: int) -> BetterHTTPRequest:
	self._max_redirects = max
	return self

func path(path: String) -> BetterHTTPRequest:
	self._url.join_mut(path)
	return self

func body(bytes: PackedByteArray) -> BetterHTTPRequest:
	self._body = bytes
	return self

func json(object: Variant) -> BetterHTTPRequest:
	self._body = JSON.stringify(object).to_utf8_buffer()
	self.header("content-type", "application/json")
	return self

func send() -> BetterHTTPResponse:
	var http = HTTPClient.new()
	return await send_with_http(http)

func send_with_http(http: HTTPClient) -> BetterHTTPResponse:
	var err = http.connect_to_host(
		self._url.host,
		self._url.port,
		TLSOptions.client() if self._url.use_ssl else null)
	assert(err == OK)

	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		await self._scene.process_frame

	assert(http.get_status() == HTTPClient.STATUS_CONNECTED)

	return await self._internal_send_with_http_no_connect(http)

func _internal_send_with_http_no_connect(http: HTTPClient) -> BetterHTTPResponse:
	var err = http.request_raw(self._method, self._url.path, self._headers, self._body)
	assert(err == OK)

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await self._scene.process_frame

	assert(http.get_status() == HTTPClient.STATUS_BODY or http.get_status() == HTTPClient.STATUS_CONNECTED)

	if !http.has_response():
		return null

	var resp = BetterHTTPResponse.new()
	resp._scene = self._scene
	resp._http = http

	if resp.status() >= 300 and resp.status() < 400:
		# -1 is used for unlimited redirects, so we can't check > 0
		assert(self._max_redirects != 0, "reached max redirects")

		self._max_redirects -= 1

		var location = resp.header("location")
		var close = true

		assert(location, "redirect must define a location header")

		if location.begins_with("/"):
			self._url.join_mut(location)
			await resp._internal_skip_body()
			close = false
		else:
			var new_url = BetterHTTPURL.parse(location)
			var eq = new_url.addr_eq(self._url)

			self._url = new_url

			# if the address is the same, reuse connection
			if eq:
				await resp._internal_skip_body()
				close = false
			else:
				http.close()
				close = true

		if not close:
			# close our side if the other side ended
			# despite setting a keep-alive header
			if http.poll() == ERR_CONNECTION_ERROR:
				close = true

		if close:
			http.close()
			return await self.send_with_http(http)
		else:
			return await self._internal_send_with_http_no_connect(http)

	return resp
