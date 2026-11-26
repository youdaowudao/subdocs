"""Loopback-only gateway used by the disposable Claude Desktop acceptance."""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Gateway(BaseHTTPRequestHandler):
    def log_message(self, _format, *_args):
        pass  # do not log headers, request bodies, or credentials

    def send_json(self, data):
        body = json.dumps(data).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.send_json({"data": [{"id": "claude-opus-5-5", "type": "model"}, {"id": "claude-sonnet-5-5", "type": "model"}]})

    def do_POST(self):
        if not self.path.split("?")[0].endswith("/v1/messages"):
            self.send_json({"input_tokens": 1})
            return
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
        print("received local /v1/messages", flush=True)
        if "test-usg-desktop" in json.dumps(body.get("messages", [])):
            print("received desktop test conversation", flush=True)
        message = {"id": "msg_local_test", "type": "message", "role": "assistant", "model": body.get("model", "claude-opus-5-5"), "content": [{"type": "text", "text": "Test OK"}], "stop_reason": "end_turn", "stop_sequence": None, "usage": {"input_tokens": 1, "output_tokens": 2}}
        if not body.get("stream"):
            self.send_json(message)
            return
        events = [
            ("message_start", {"message": {**message, "content": [], "stop_reason": None, "usage": {"input_tokens": 1, "output_tokens": 0}}}),
            ("content_block_start", {"index": 0, "content_block": {"type": "text", "text": ""}}),
            ("content_block_delta", {"index": 0, "delta": {"type": "text_delta", "text": "Test OK"}}),
            ("content_block_stop", {"index": 0}),
            ("message_delta", {"delta": {"stop_reason": "end_turn", "stop_sequence": None}, "usage": {"output_tokens": 2}}),
            ("message_stop", {}),
        ]
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for event, data in events:
            self.wfile.write(f"event: {event}\ndata: {json.dumps({'type': event, **data})}\n\n".encode())
        self.wfile.flush()


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Gateway).serve_forever()
