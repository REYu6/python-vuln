# Artifact HTML served inline same-origin without CSP

**Verification: CODE-VERIFIED**

## Description
Attacker-writable artifact HTML served as text/html in same origin. No CSP, no sandbox, no Content-Disposition.

## Impact
Same-origin XSS chains with reveal_key (#1) for credential theft.

## PoC
```bash
curl -X POST http://localhost:8000/api/v1/artifacts -F "file=@payload.html;type=text/html"
```

## Execution result
```
Code path analysis: no CSP/sandbox/Content-Disposition on artifact serving.
```
