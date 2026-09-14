# Archery: /audit/input/ lets any logged-in user write indistinguishable audit entries (hardening, not a vulnerability)

**Verification: CODE-VERIFIED with corrected analysis** (an earlier revision of this report claimed arbitrary-identity forgery — that was wrong and is corrected here)

## What the endpoint actually does

`POST /audit/input/` (`sql/audit_log.py:24-43`) is the designed submission point for frontend-generated audit events:

```python
@login_required
def audit_input(request):
    action = request.POST.get("action")
    extra_info = request.POST.get("extra_info", "")
    result["user_id"] = request.user.id          # identity from SERVER-SIDE session
    result["user_name"] = request.user.username
    result["user_display"] = request.user.display
    result["action"] = action                     # client-controlled free text
    result["extra_info"] = extra_info             # client-controlled free text
    AuditEntry(**result).save()
```

Only `action` and `extra_info` are client-controlled. **The identity fields cannot be forged** — an earlier revision of this report claimed `user=admin` forgery via POST; that is incorrect (identity comes from `request.user`), and that PoC has been withdrawn.

## Residual issue (hardening class)

Any logged-in user can write audit entries **attributed to themselves** with arbitrary `action`/`extra_info` text, stored with no distinction from machine-generated events (login/logout/failure callbacks write the same model). Consequences: audit-log noise, and self-authored records that a reviewer cannot distinguish from system-emitted ones — an integrity weakness of the audit trail, not a privilege boundary violation. Attack attribution in forensics is not affected (no impersonation possible).

## Recommendation

Tag `AuditEntry` records with a source field (`system` vs `user-submitted`) or restrict the endpoint to a server-side allowlist of action codes; rate-limit submissions. Filing as a hardening suggestion, not a security vulnerability.
