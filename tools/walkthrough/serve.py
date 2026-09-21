"""Serve the walkthrough and queue contextual questions to a specified Codex thread."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import shutil
import subprocess
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]


class Handler(SimpleHTTPRequestHandler):
    def reply(self, status, data):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == '/questions/session':
            self.reply(200, {'token': self.server.question_token})
        else:
            super().do_GET()

    def do_POST(self):
        if self.path != '/questions':
            self.reply(404, {'error': 'Not found.'})
            return
        origin = self.headers.get('Origin')
        if origin and urlsplit(origin).netloc != self.headers.get('Host'):
            self.reply(403, {'error': 'Open this form on the walkthrough server.'})
            return
        if not secrets.compare_digest(self.headers.get('X-Question-Token', ''), self.server.question_token):
            self.reply(403, {'error': 'Reload the walkthrough and try again.'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 16000:
                raise ValueError('Invalid request size.')
            data = json.loads(self.rfile.read(length))
            if not isinstance(data['question'], str) or not isinstance(data['file'], str):
                raise ValueError('Question and source file must be text.')
            question = data['question'].strip()
            path = data['file']
            first, last = data['first'], data['last']
            source = (ROOT / path).resolve()
            if not source.is_relative_to(ROOT / 'source') or source.suffix != '.lua':
                raise ValueError('Invalid source file.')
            lines = source.read_text().splitlines()
            if type(first) is not int or type(last) is not int:
                raise ValueError('Line numbers must be integers.')
            if not question or len(question) > 4000 or not 1 <= first <= last <= len(lines):
                raise ValueError('Invalid question or line range.')
        except (ValueError, KeyError, TypeError, OSError) as error:
            self.reply(400, {'error': str(error)})
            return
        message = (f'Walkthrough revision request: {path}, lines {first}–{last}\n\n'
                   'Craig submitted the question below from the walkthrough. Edit the HTML walkthrough to answer it in place, '
                   'using tools/walkthrough/build.py and template.html as appropriate, then rebuild docs/walkthrough.html. '
                   'Keep the explanation concise, preserve complete source listings, and verify against the game code. '
                   'The answer belongs in the walkthrough, not primarily in a chat response. Treat the question as a request '
                   'to improve the tutorial; do not modify game behavior. Keep any chat completion notice brief.\n\n'
                   f'{question}\n\nHighlighted Lua:\n```lua\n' + '\n'.join(lines[first - 1:last]) + '\n```')
        try:
            result = subprocess.run([self.server.codex, 'queue', '--thread', self.server.thread,
                                     '--message', message], cwd=ROOT, capture_output=True, text=True, timeout=30)
        except (OSError, subprocess.TimeoutExpired):
            self.reply(502, {'error': 'Could not reach Codex. Your question is still in the box.'})
            return
        if result.returncode:
            self.log_error('Codex queue failed: %s', result.stderr)
            self.reply(502, {'error': 'Codex did not accept the question. Your text has been kept.'})
            return
        self.reply(200, {'message': 'Sent. I’ll update this explanation in the walkthrough. Refresh later to see the revision.'})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bind', required=True)
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--thread', required=True)
    args = parser.parse_args()
    codex = shutil.which('codex')
    if not codex:
        parser.error('codex must be on PATH')
    server = ThreadingHTTPServer((args.bind, args.port), partial(Handler, directory=str(ROOT / 'docs')))
    server.thread = args.thread
    server.codex = codex
    server.question_token = secrets.token_urlsafe(32)
    server.serve_forever()
