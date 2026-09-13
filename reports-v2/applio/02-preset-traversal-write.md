# FD-001: Preset name traversal writes JSON outside assets/presets

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`export_presets_button` in `tabs/inference/inference.py:189-191` joins `preset_name` into `os.path.join(PRESETS_DIR, f"{preset_name}.json")` without sanitization. A name containing `../../` writes outside the presets directory.

## Impact
Unauthenticated client creates/overwrites arbitrary `.json` files at any existing parent directory reachable via traversal from `assets/presets/`.

## PoC
```python
c.predict(preset_name="../../poc/FD001_ESCAPED", pitch=0, index_rate=0.5,
          rms_mix_rate=0.25, protect=0.33, api_name="/export_presets_button")
```

## Execution result
```
[FD-001] {"verdict": "REPRODUCED", "created": true, "func_return": "Export successful"}
```
