# Malicious .pth → RCE via inference CLI --model_path

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
7 inference scripts call torch.load(args.model_path)['params']. Pickle opcodes execute before key indexing fails.

## Impact
Malicious checkpoint author → inference host RCE.

## PoC
```
```python
# inference_basicvsr.py:37 (same pattern in 7 scripts):
model.load_state_dict(torch.load(args.model_path)["params"], strict=True)
# torch.load executes pickle opcodes BEFORE ["params"] indexing fails

# Full CLI reproduction:
# python inference/inference_esrgan.py --model_path evil.pth --input input.png --output out/
```
```

## Execution result
```
REPRODUCED: side-effect file created despite error
```
