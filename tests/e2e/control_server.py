#!/usr/bin/env python3
import itertools
import json
import socket
import threading
import time


class ControlError(Exception):
    pass


class ControlTimeout(ControlError):
    pass


class ControlConnection:
    def __init__(self, sock):
        self._sock = sock
        self._lock = threading.Lock()
        self._condition = threading.Condition(self._lock)
        self._responses = {}
        self._closed = False
        self._failure = None
        self.instance = None

    def send_command(self, request_id, name, args):
        frame = json.dumps({"id": request_id, "command": name, "args": args}) + "\n"
        try:
            self._sock.sendall(frame.encode("utf-8"))
        except OSError as error:
            raise ControlError("failed to send %s to %s: %s" % (name, self.instance, error))

    def deliver_response(self, response):
        request_id = response.get("id")
        with self._condition:
            self._responses[request_id] = response
            self._condition.notify_all()

    def fail(self, message):
        with self._condition:
            if self._failure is None:
                self._failure = message
            self._closed = True
            self._condition.notify_all()

    def close(self):
        with self._condition:
            self._closed = True
            self._condition.notify_all()
        try:
            self._sock.close()
        except OSError:
            pass

    def wait_response(self, request_id, deadline):
        with self._condition:
            while request_id not in self._responses:
                if self._failure is not None:
                    raise ControlError("control link to %s failed: %s" % (self.instance, self._failure))
                if self._closed:
                    raise ControlError("control link to %s closed before response %d" % (self.instance, request_id))
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise ControlTimeout("timed out waiting for response %d from %s" % (request_id, self.instance))
                self._condition.wait(remaining)
            return self._responses.pop(request_id)


class ControlServer:
    def __init__(self, host="127.0.0.1"):
        self._listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._listener.bind((host, 0))
        self._listener.listen(8)
        _, self.port = self._listener.getsockname()
        self._ids = itertools.count(1)
        self._lock = threading.Lock()
        self._condition = threading.Condition(self._lock)
        self._instances = {}
        self._connections = []
        self._stopped = False
        self._accept_thread = threading.Thread(target=self._accept_loop, daemon=True)
        self._accept_thread.start()

    def _accept_loop(self):
        while True:
            try:
                sock, _ = self._listener.accept()
            except OSError:
                return
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            connection = ControlConnection(sock)
            with self._lock:
                if self._stopped:
                    connection.close()
                    return
                self._connections.append(connection)
            reader = threading.Thread(target=self._read_loop, args=(connection, sock), daemon=True)
            reader.start()

    def _read_loop(self, connection, sock):
        buffer = b""
        while True:
            try:
                chunk = sock.recv(65536)
            except OSError as error:
                connection.fail(str(error))
                return
            if not chunk:
                connection.close()
                return
            buffer += chunk
            while b"\n" in buffer:
                raw, buffer = buffer.split(b"\n", 1)
                if not raw.strip():
                    continue
                try:
                    message = json.loads(raw.decode("utf-8"))
                except ValueError as error:
                    connection.fail("invalid json frame: %s" % error)
                    return
                self._dispatch(connection, message)

    def _dispatch(self, connection, message):
        if "hello" in message:
            hello = message["hello"]
            instance = hello.get("instance") if isinstance(hello, dict) else None
            if not instance:
                connection.fail("hello frame missing instance")
                return
            with self._condition:
                existing = self._instances.get(instance)
                if existing is not None and existing is not connection:
                    connection.fail("duplicate instance %s" % instance)
                    return
                connection.instance = instance
                self._instances[instance] = connection
                self._condition.notify_all()
            return
        if "id" in message:
            connection.deliver_response(message)
            return
        connection.fail("unexpected frame %r" % message)

    def wait_for_instance(self, instance, timeout):
        deadline = time.monotonic() + timeout
        with self._condition:
            while instance not in self._instances:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise ControlTimeout("instance %s never connected to the control server" % instance)
                self._condition.wait(remaining)
            return self._instances[instance]

    def has_instance(self, instance):
        with self._lock:
            return instance in self._instances

    def request(self, instance, name, args=None, timeout=20.0):
        deadline = time.monotonic() + timeout
        connection = self.wait_for_instance(instance, timeout)
        request_id = next(self._ids)
        connection.send_command(request_id, name, args or {})
        response = connection.wait_response(request_id, deadline)
        if not response.get("ok", False):
            raise ControlError("%s command %s failed: %s" % (instance, name, response.get("error", "unknown error")))
        return response.get("result", {})

    def stop(self):
        with self._lock:
            self._stopped = True
            connections = list(self._connections)
        try:
            self._listener.close()
        except OSError:
            pass
        for connection in connections:
            connection.close()
