class_name BetterHTTPURL

var host: String
var port: int
var path: String
var query: String
var hash: String

var use_ssl: bool

static func parse_path(url: String) -> BetterHTTPURL:
	var path_delim = url.find("/")
	var path: String

	if path_delim != -1:
		path = url.substr(path_delim)
	else:
		path = ""

	var query: String
	var hash: String

	# check for #
	var hash_delim: int = path.find('#')

	if hash_delim != -1:
		hash = path.substr(hash_delim)
		path = path.substr(0, hash_delim)

	# check for ?
	var query_delim: int = path.find("?")

	if query_delim != -1:
		query = path.substr(query_delim + 1)
		path = path.substr(0, query_delim)

	var u = BetterHTTPURL.new()

	u.path = path
	u.query = query
	u.hash = hash

	return u

static func parse(url: String) -> BetterHTTPURL:
	var use_ssl: bool = url.begins_with("https://")
	var host: String
	var port: int = -1

	url = url.trim_prefix("http://").trim_prefix("https://")

	var path_delim: int = url.find("/")
	var port_delim: int

	var u = BetterHTTPURL.parse_path(url)

	var has_port: bool
	var host_length: int

	if url[0] == "[":
		var end: int = url.find("]")
		if end == -1:
			port_delim = url.find(":", end)
			has_port = port_delim != -1 and port_delim < path_delim
			host_length = end + 1 if not has_port else port_delim
	else:
		port_delim = url.find(":")
		has_port = port_delim != -1 and (port_delim < path_delim or path_delim == -1)
		host_length = path_delim if not has_port else port_delim

	host = url.substr(0, host_length)

	if has_port:
		var port_length: int = (
			path_delim - port_delim if path_delim > 0
			else url.length() - port_delim)

		port = url.substr(port_delim, port_length).to_int()

	u.host = host
	u.port = port
	u.use_ssl = use_ssl

	return u

func clone() -> BetterHTTPURL:
	var url = BetterHTTPURL.new()
	
	url.host = self.host
	url.port = self.port
	url.path = self.path
	url.use_ssl = self.use_ssl
	url.query = self.query
	url.hash = self.hash
	
	return url

func join(path: String) -> BetterHTTPURL:
	return self.clone().join_mut(path)

func join_mut(path: String) -> BetterHTTPURL:
	var other = BetterHTTPURL.parse_path(path)

	# merge path
	match [self.path.ends_with("/"), other.path.begins_with("/")]:
		[true, true]:
			self.path = self.path.substr(0, self.path.length() - 1) + other.path
		[true, false], [false, true]:
			self.path += other.path
		[false, false]:
			self.path += "/" + other.path

	# merge query
	if not other.query.is_empty():
		if not self.query.is_empty():
			self.query += "&"
		self.query += other.query

	# overwrite hash if given
	if not other.hash.is_empty():
		self.hash = other.hash

	return self

func stringify() -> String:
	var url: String = "http" + ("s" if self.use_ssl else "") + "://" + self.http_host() + self.path

	if self.query.length():
		url += "?" + self.query

	url += self.hash

	return url

# returns the http host (host + port) for use in a Host header
func http_host() -> String:
	var host = self.host

	if self.port != -1:
		host += ":" + str(self.port)

	return host

# returns true if the old and new URLs represent different addresses
func addr_eq(other: BetterHTTPURL) -> bool:
	return self.host == other.host and self.port == other.port and self.use_ssl == other.use_ssl

