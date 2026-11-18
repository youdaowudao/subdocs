"""Local gateway for the real Windows assistant's isolated UI test."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import time


class Gateway(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.headers.get('Authorization') != 'Bearer sk-picture-test-fixture':
            self.send_error(401)
            return
        if self.path == '/v1/usage':
            with (self.server.work / 'imports.txt').open('a', encoding='utf-8') as log:
                log.write('usage\n')
            for _ in range(80):
                if not (self.server.work / 'hold').exists():
                    break
                time.sleep(0.1)
            payload = {'isValid': True, 'remaining': 10}
        elif self.path == '/v1/models':
            payload = {'data': [{'id': 'gpt-image-2.5-flare'}]}
        else:
            self.send_error(404)
            return
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    args = parser.parse_args()
    with ThreadingHTTPServer(('127.0.0.1', 19471), Gateway) as server:
        server.work = args.work
        (server.work / 'ready').touch()
        server.serve_forever()
