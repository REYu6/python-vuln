**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description

When a handler has already sent part of a `StreamResponse` body and then raises an `HTTPException`, `RequestHandler._handle_request` (`aiohttp/web_protocol.py`) takes the `HTTPException` branch, which bypasses the `output_size` guard that the normal error path (`handle_error`) uses. A full second response — new status line + headers + error body — is written onto the same connection right after the already-transmitted partial body.

## Impact

One connection, two HTTP responses on the wire: `200 ... PARTIAL-BODY-HTTP/1.1 400 ...`. Downstream intermediaries that resplit this stream can mis-associate the injected second "response" with a later request (response splitting / cache poisoning precondition). Requires an application pattern of "write part of the body, then raise HTTPException" with a remotely triggerable condition — not rare in streaming endpoints that abort on invalid input mid-stream.

## PoC

Verified on current master snapshot:

```python
async def stream(request):
    resp = web.StreamResponse(status=200)
    await resp.prepare(request)
    await resp.write(b"PARTIAL-BODY-")
    if "boom" in request.query:
        raise web.HTTPBadRequest(text="error page after partial body")
    await resp.write(b"done")
    return resp
```

Raw socket client: `GET /stream?boom=1`, then read everything on the wire.

## Execution result

```
HTTP/1.1 200 OK
Content-Type: text/plain
Transfer-Encoding: chunked
Date: Mon, 07 Sep 2026 14:36:05 GMT
Server: Python/3.12 aiohttp/4.0.0a2.dev0

d
PARTIAL-BODY-
HTTP/1.1 400 Bad Request
Content-Type: text/plain; charset=utf-8
Content-Length: 29
Date: Mon, 07 Sep 2026 14:36:05 GMT
Server: Python/3.12 aiohttp/4.0.0a2.dev0

1d
error page after partial body
0

[RESULT] {"first_status_line": "HTTP/1.1 200 OK",
          "second_status_line_emitted_mid_body": true, "verdict": "REPRODUCED"}
```

The second status line and headers appear verbatim inside the chunked body of the first response.
