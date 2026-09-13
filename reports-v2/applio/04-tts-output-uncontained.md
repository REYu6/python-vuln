# FD-004: TTS output path uncontained write

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`run_tts_script` in `core.py:341-365`: the deletion guard requires the `assets/` prefix, but the write via `subprocess(tts.py) → edge_tts.save(output_tts_path)` has no containment — read/delete guards are asymmetric with writes.

## Impact
Unauthenticated client writes TTS output to an arbitrary absolute path.

## PoC
```python
from core import run_tts_script
run_tts_script(..., output_tts_path="/arbitrary/path/FD004_ESCAPED.wav", ...)
```

## Execution result
```
[FD-004] {"verdict": "REPRODUCED", "created": true}
```
