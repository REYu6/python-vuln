# FD-009: Remote shutdown command via training tab checkbox

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
The training-tab shutdown checkbox (client-controlled) causes `shutdown_after_training()` in `core.py:488-514` to issue `os.system("shutdown /s /t 300")` on Windows / `os.system("shutdown -h +5")` on Linux with constant arguments.

## Impact
Unauthenticated web client schedules host power-off — an availability lever against the training machine.

## PoC
```python
# In the Training tab, check "Shutdown after training", then click Start Training.
# The checkbox value flows into run_train_script(shutdown_after_training=True)
# which calls core.py:shutdown_after_training() -> os.system("shutdown -h +5")

# Direct function call (same function the GUI invokes):
from core import shutdown_after_training
shutdown_after_training()
```

## Execution result
```
[FD-009] {"verdict": "REPRODUCED", "captured_command": "shutdown -h +5"}
```
