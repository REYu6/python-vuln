# FD-015: Blend name traversal writes .pth outside logs/

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`model_blender` in `rvc/train/process/model_blender.py:71` executes `torch.save(opt, os.path.join("logs", f"{name}.pth"))` where `name` is a free-text field from the voice blender tab, with no sanitization.

## Impact
Unauthenticated client writes a `.pth`-suffixed file at any path reachable via traversal from `logs/`, and reads arbitrary checkpoint files as blend inputs.

## PoC
```python
c.predict("../../poc/FD015_PWNED", model_a, model_b, 0.5, api_name="/_blend_with_toast")
```

## Execution result
```
[FD-015] {"verdict": "REPRODUCED", "created": true}
```
