"""Aplicação de exemplo: responde em JSON com o nome do container."""

import json
import signal
import socket
import sys
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        resposta = {
            "servico": "app-equipe",
            "container": socket.gethostname(),
            "hora": datetime.now().isoformat(timespec="seconds"),
            "caminho": self.path,
        }
        corpo = json.dumps(resposta).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(corpo)


def encerrar(sinal, quadro):
    sys.exit(0)


signal.signal(signal.SIGTERM, encerrar)

HTTPServer(("0.0.0.0", 5000), Handler).serve_forever()
