"""A stand-in model server for Codex, used to check the image tool's rules.

Codex is pointed at this server instead of a real model. When a turn starts,
the server answers with one shell call running the command in the file given
by --command-file; once Codex sends the command's result back, it ends the
turn. Every request and every command result is written to --log-dir, so a
test can see which tool Codex offered, whether the command ran and what it
printed. No key and no network access are needed.
"""

import argparse
import itertools
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

counter = itertools.count(1)
lock = threading.Lock()


def shell_call(tools, command):
    """Picks the shell tool Codex offered and fills in its arguments."""
    names = [tool.get("name") for tool in tools if isinstance(tool, dict)]
    if "shell_command" in names:
        return "shell_command", {"command": command}
    if "exec_command" in names:
        return "exec_command", {"cmd": command}
    if "shell" in names:
        shell = ["powershell.exe", "-NoProfile", "-Command"] if os.name == "nt" else ["bash", "-lc"]
        return "shell", {"command": shell + [command]}
    raise ValueError("Codex offered no shell tool: %s" % names)


def call_outputs(body):
    return [item for item in body.get("input", []) if isinstance(item, dict) and item.get("type", "").endswith("call_output")]


def sse(handler, events):
    handler.send_response(200)
    handler.send_header("Content-Type", "text/event-stream")
    handler.send_header("Cache-Control", "no-cache")
    handler.end_headers()
    for event in events:
        handler.wfile.write(("event: %s\ndata: %s\n\n" % (event["type"], json.dumps(event, ensure_ascii=False))).encode("utf-8"))
    handler.wfile.flush()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "mock-responses"

    def log_message(self, format, *arguments):
        sys.stderr.write("mock: " + format % arguments + "\n")

    def record(self, name, data):
        with open(os.path.join(self.server.log_dir, name), "a", encoding="utf-8") as file:
            file.write(json.dumps(data, ensure_ascii=False) + "\n")

    def do_GET(self):
        self.record("requests.jsonl", {"method": "GET", "path": self.path})
        body = json.dumps({"object": "list", "data": [], "models": []}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length)
        try:
            body = json.loads(raw or b"{}")
        except ValueError:
            body = {}
        with lock:
            number = next(counter)
        tools = body.get("tools") or []
        outputs = call_outputs(body)
        self.record("requests.jsonl", {
            "number": number,
            "path": self.path,
            "model": body.get("model"),
            "tools": [tool.get("name") or tool.get("type") for tool in tools if isinstance(tool, dict)],
            "outputs": len(outputs),
        })
        if not self.path.rstrip("/").endswith("/responses"):
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        response_id = "resp_%d" % number
        created = {"type": "response.created", "response": {"id": response_id}}
        usage = {"input_tokens": 1, "input_tokens_details": None, "output_tokens": 1,
                 "output_tokens_details": None, "total_tokens": 2}
        completed = {"type": "response.completed", "response": {"id": response_id, "usage": usage}}
        if outputs:
            for output in outputs:
                self.record("outputs.jsonl", output)
            item = {"type": "message", "role": "assistant", "id": "msg_%d" % number,
                    "content": [{"type": "output_text", "text": "完成"}]}
        else:
            with open(self.server.command_file, encoding="utf-8-sig") as file:
                command = file.read().strip()
            name, arguments = shell_call(tools, command)
            self.record("calls.jsonl", {"tool": name, "arguments": arguments})
            item = {"type": "function_call", "id": "fc_%d" % number, "call_id": "call_%d" % number,
                    "name": name, "arguments": json.dumps(arguments, ensure_ascii=False), "status": "completed"}
        sse(self, [created, {"type": "response.output_item.done", "output_index": 0, "item": item}, completed])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port-file", required=True)
    parser.add_argument("--log-dir", required=True)
    parser.add_argument("--command-file", required=True)
    options = parser.parse_args()
    os.makedirs(options.log_dir, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.log_dir = options.log_dir
    server.command_file = options.command_file
    with open(options.port_file, "w", encoding="utf-8") as file:
        file.write(str(server.server_address[1]))
    server.serve_forever()


if __name__ == "__main__":
    main()
