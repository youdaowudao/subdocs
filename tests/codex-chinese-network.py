"""Only for Actions: deterministic CDP failures, stalled TLS and NXDOMAIN. No credentials."""
import argparse
import base64
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import socketserver
import struct
import threading
import time


def exact(stream, size):
    data = b''
    while len(data) < size:
        part = stream.read(size - len(data))
        if not part:
            raise EOFError()
        data += part
    return data


def frame(connection, message, final=True, opcode=1):
    data = json.dumps(message).encode() if not isinstance(message, bytes) else message
    size = len(data)
    length = bytes([size]) if size < 126 else b'\x7e' + struct.pack('!H', size)
    connection.sendall(bytes([(128 if final else 0) | opcode]) + length + data)


def cdp(mode, ready):
    attempts = []

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            if self.path == '/json/list':
                body = json.dumps([dict(type='page', url='app://-/index.html',
                                       webSocketDebuggerUrl=f'ws://127.0.0.1:{self.server.server_port}/devtools/page/current')]).encode()
                self.send_response(200)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            if mode == 'handshake-hang':
                time.sleep(300)
                return
            accept = base64.b64encode(hashlib.sha1((self.headers['Sec-WebSocket-Key'] +
                                       '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
            self.send_response(101)
            self.send_header('Upgrade', 'websocket')
            self.send_header('Connection', 'Upgrade')
            self.send_header('Sec-WebSocket-Accept', accept)
            self.end_headers()
            if mode == 'send-hang':
                time.sleep(300)
                return
            try:
                a, b = exact(self.rfile, 2)
                size = b & 127
                if size == 126:
                    size = struct.unpack('!H', exact(self.rfile, 2))[0]
                elif size == 127:
                    size = struct.unpack('!Q', exact(self.rfile, 8))[0]
                mask = exact(self.rfile, 4) if b & 128 else None
                data = exact(self.rfile, size)
                if mask:
                    data = bytes(v ^ mask[i % 4] for i, v in enumerate(data))
                request = json.loads(data)
                attempts.append(time.monotonic())
                ready.with_suffix('.attempts').write_text(str(len(attempts)))
                if mode == 'receive-hang':
                    time.sleep(300)
                    return
                if mode == 'events':
                    for _ in range(300):
                        frame(self.connection, {'method': 'Runtime.consoleAPICalled', 'params': {}})
                        time.sleep(1)
                    return
                if mode in ('race', 'always-race', 'other-error') and (len(attempts) == 1 or mode != 'race'):
                    message = 'Execution context was destroyed.' if mode != 'other-error' else 'Permission denied'
                    frame(self.connection, {'id': request['id'], 'error': {'code': -32000, 'message': message}})
                    return
                response = {'id': request['id'], 'result': {'result': {'type': 'string', 'value': '{"ok":true}'}}}
                if mode == 'fragmented':
                    data = json.dumps(response).encode()
                    frame(self.connection, data[:30], False)
                    frame(self.connection, data[30:], True, 0)
                else:
                    frame(self.connection, response)
            except (OSError, EOFError):
                pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    ready.write_text(str(server.server_port))
    server.serve_forever()


def network(mode, ready):
    if mode == 'dns-fail':
        class DNS(socketserver.BaseRequestHandler):
            def handle(self):
                request, stream = self.request
                # NXDOMAIN; retain the exact question, return no answers.
                response = request[:2] + b'\x81\x83' + request[4:6] + b'\0' * 6 + request[12:]
                stream.sendto(response, self.client_address)
        server = socketserver.ThreadingUDPServer(('127.0.0.1', 53), DNS)
    else:
        class Hang(socketserver.BaseRequestHandler):
            def handle(self):
                # Hold the TLS connection for five minutes; never reply or reject it.
                self.request.settimeout(300)
                time.sleep(300)
        server = socketserver.ThreadingTCPServer(('127.0.0.2', 443), Hang)
    server.daemon_threads = True
    ready.write_text('ready')
    server.serve_forever()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', required=True)
    parser.add_argument('--ready', type=Path, required=True)
    args = parser.parse_args()
    if args.mode in ('dns-fail', 'longhang'):
        network(args.mode, args.ready)
    else:
        cdp(args.mode, args.ready)
