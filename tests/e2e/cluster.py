#!/usr/bin/env python3
import os
import pathlib
import socket
import subprocess
import time

from control_server import ControlServer, ControlError, ControlTimeout


REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
ARTIFACTS_DIR = REPO_ROOT / "artifacts" / "e2e"

SERVER_INSTANCE = "server"
ALICE_INSTANCE = "alice"
BOB_INSTANCE = "bob"


def free_udp_port(host="127.0.0.1"):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind((host, 0))
        return sock.getsockname()[1]
    finally:
        sock.close()


class GodotProcess:
    def __init__(self, instance, popen_args, stdout_path, stderr_path):
        self.instance = instance
        self.popen_args = popen_args
        self._stdout_path = stdout_path
        self._stderr_path = stderr_path
        self._stdout = None
        self._stderr = None
        self._process = None

    @property
    def pid(self):
        return self._process.pid if self._process is not None else None

    def start(self):
        self._stdout = open(self._stdout_path, "wb")
        self._stderr = open(self._stderr_path, "wb")
        self._process = subprocess.Popen(
            self.popen_args,
            cwd=str(REPO_ROOT),
            stdout=self._stdout,
            stderr=self._stderr,
            stdin=subprocess.DEVNULL,
        )

    def exit_code(self):
        if self._process is None:
            return None
        return self._process.poll()

    def terminate(self, grace=8.0):
        if self._process is None:
            self._close_logs()
            return
        if self._process.poll() is None:
            self._process.terminate()
            deadline = time.monotonic() + grace
            while self._process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.05)
            if self._process.poll() is None:
                self._process.kill()
                try:
                    self._process.wait(timeout=grace)
                except subprocess.TimeoutExpired:
                    pass
        self._close_logs()

    def _close_logs(self):
        for handle in (self._stdout, self._stderr):
            if handle is not None:
                try:
                    handle.flush()
                    handle.close()
                except OSError:
                    pass
        self._stdout = None
        self._stderr = None

    def stderr_tail(self, limit=4000):
        try:
            data = pathlib.Path(self._stderr_path).read_bytes()
        except OSError:
            return ""
        return data[-limit:].decode("utf-8", "replace")


class Cluster:
    def __init__(self, godot_bin=None, artifacts_dir=ARTIFACTS_DIR):
        self.godot_bin = godot_bin or os.environ.get("GODOT_BIN", "godot")
        self.artifacts_dir = pathlib.Path(artifacts_dir)
        self.artifacts_dir.mkdir(parents=True, exist_ok=True)
        self.control = ControlServer()
        self.game_port = free_udp_port()
        self.processes = {}

    def _engine_args(self, user_args):
        return [self.godot_bin, "--headless", "--path", str(REPO_ROOT), "--"] + user_args

    def _launch(self, instance, user_args):
        stdout_path = self.artifacts_dir / ("%s.stdout.log" % instance)
        stderr_path = self.artifacts_dir / ("%s.stderr.log" % instance)
        process = GodotProcess(instance, self._engine_args(user_args), stdout_path, stderr_path)
        process.start()
        self.processes[instance] = process
        return process

    def start_server(self):
        return self._launch(SERVER_INSTANCE, [
            "server", "E2E", str(self.game_port), "2", "deathmatch",
            "--e2e", "--e2e-instance", SERVER_INSTANCE, "--e2e-control-port", str(self.control.port),
        ])

    def start_client(self, instance):
        return self._launch(instance, [
            "connect", "127.0.0.1", str(self.game_port),
            "--e2e", "--e2e-instance", instance, "--e2e-control-port", str(self.control.port),
        ])

    def assert_alive(self, instance):
        process = self.processes[instance]
        code = process.exit_code()
        if code is not None:
            raise ControlError("instance %s exited early with code %s\n%s" % (instance, code, process.stderr_tail()))

    def await_connection(self, instance, timeout=30.0):
        deadline = time.monotonic() + timeout
        while not self.control.has_instance(instance):
            self.assert_alive(instance)
            if time.monotonic() > deadline:
                raise ControlTimeout("instance %s never connected to the control server\n%s" % (
                    instance, self.processes[instance].stderr_tail()))
            time.sleep(0.1)

    def command(self, instance, name, args=None, timeout=20.0):
        self.assert_alive(instance)
        return self.control.request(instance, name, args, timeout)

    def terminate(self, instance):
        process = self.processes.get(instance)
        if process is not None:
            process.terminate()

    def stop(self):
        for process in self.processes.values():
            process.terminate()
        self.control.stop()
