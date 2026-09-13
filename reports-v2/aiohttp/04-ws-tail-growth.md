**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description

After a WebSocket reader error on an upgraded client connection, data keeps accumulating in `ResponseHandler._tail` without any cap:

1. `WebSocketReader.feed_data` (`aiohttp/_websocket/reader_py.py`) sets `self._exc` on the first protocol error and afterwards returns `(True, data)` immediately for any further data.
2. `ResponseHandler.data_received` (`aiohttp/client_proto.py`) then clears `_payload_parser` on `eof=True` but **keeps `_upgraded = True`**, so every subsequent byte takes the `if self._upgraded or self._parser is None: self._tail += data` branch — unbounded growth, as long as nothing closes the connection.

Importantly, the error is only surfaced (and the connection closed via `receive()` → `close()`) if the application actually calls `receive()`. A long-lived client that connects and never reads (heartbeat senders, idle monitors, apps waiting on a timer) never triggers that path.

## Impact

A malicious WebSocket server can drive the client process out of memory: send one protocol-violating frame, then push an endless byte stream — the client buffers all of it in `_tail`. Related prior art: PR #13393 / #13488 added accounting for queue and per-read fragmentation, but this post-error `_tail` path is not covered by those bounds.

## PoC

Verified on current master snapshot (pure-Python reader; note that `reader_c` shares the `_exc` short-circuit pattern). Evil server: complete the ws handshake, send one RSV2-set frame (`bytes([0b01000001, 0x01]) + b"x"`) to trigger `WebSocketError`, then stream 64 MiB of raw bytes. Victim client connects and — like a long-lived idle client — never calls `receive()`/`close()`:

```python
async with aiohttp.ClientSession() as s:
    async with s.ws_connect("http://127.0.0.1:8095/") as ws:
        await asyncio.sleep(6)     # server pushes 64 MiB into _tail meanwhile
```

## Execution result

```
[victim] app never calls receive()/close() after connect (long-lived idle ws client)
[evidence] RSS before error 31.6 MiB, after error 31.8 MiB, after server pushed 64 MiB: 97.3 MiB
[RESULT] {"poc": "aiohttp-12-ws-tail-unbounded",
          "rss_before_error_mib": 31.8, "rss_after_push_mib": 97.3,
          "rss_growth_mib": 65.5, "server_bytes_pushed_mib": 64,
          "verdict": "REPRODUCED"}
```

RSS growth matches the pushed bytes 1:1 — all 64 MiB sit in `_tail`. (For completeness: if the application *does* call `receive()`, `client_ws.receive()` closes the connection on the surfaced `WebSocketError`, so the growth condition is exactly the never-reading client.)
