# Unauthenticated reveal_key returns provider API keys

**Verification: CODE-VERIFIED** (source path analysis; no runtime execution performed)

## Description

`backend/core_api/cowork/api/v1/endpoints/settings.py` defines:

```python
@router.get("/reveal-key/{name}")
def reveal_key(name: str, session: SessionDep):
    field_map = {
        "anthropic": "anthropic_api_key",
        "openai": "openai_api_key",
        "minds": "minds_api_key",
    }
    s = SettingService(session).load()
    val = getattr(s, field)
    return {"value": val.get_secret_value() if isinstance(val, SecretStr) else ""}
```

The endpoint has **no authentication dependency** (only `session: SessionDep` for DB access). It returns the unmasked `get_secret_value()` of the provider API key. Combined with the app-level CORS policy (`'*'` + origin reflection), any website the operator visits can cross-origin read these keys.

## Impact

Operator's browser visits a malicious page → the page sends `fetch('http://localhost:<port>/api/v1/settings/reveal-key/anthropic', {mode: 'cors'})` → the operator's Anthropic API key is returned in the response body. This is a drive-by credential theft: the attacker's website never needs to run code on the victim's machine, only to know the local API port.

## PoC

```bash
# Assuming the core_api service is running locally on its default port:
curl http://localhost:8000/api/v1/settings/reveal-key/anthropic
# Expected response: {"value": "sk-ant-api03-..."}
```

## Execution result

```
Verification level: code path analysis only.
Evidence: settings.py L92-103 — endpoint has no auth dependency,
          calls get_secret_value() and returns it in the JSON response body.
          No authentication middleware on the router.
```
