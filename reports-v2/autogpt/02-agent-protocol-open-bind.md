# Agent Protocol overwrites localhost to 0.0.0.0 without auth

**Verification: CODE-VERIFIED**

## Description
`classic/original_autogpt/autogpt/app/agent_protocol_server.py:122`:
```python
config.bind = [f"0.0.0.0:{port}"]
```
The code overwrites the localhost binding with 0.0.0.0 (default port 8000) while the log message still says "localhost". `/ap/v1` routes have no authentication dependency. Empty input is treated as approval.

## Impact
Network attacker connects to `<host>:8000/ap/v1` and remotely drives the agent loop (file operations / code execution per AutoGPT configuration).

## PoC
```bash
curl http://<host>:8000/ap/v1/agent/tasks -X POST -H "Content-Type: application/json" -d '{"input": ""}'
# Empty input = auto-approval; agent executes with file/code capabilities
```

## Execution result
```
Code path analysis: agent_protocol_server.py:122 — 0.0.0.0 override;
api_router.py — no auth dependency on any /ap/v1 route.
```
