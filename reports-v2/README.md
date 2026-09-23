# 漏洞报告总索引 — reports-v2

62 个审计项目 × 技能五因子复核；本目录只保留**已上报上游**或**已动态复现（DYNAMICALLY-REPRODUCED）**的报告，每项目一目录、每漏洞一文件。

## 目录结构

```
reports-v2/
├── README.md          ← 本索引
├── aim/               (4 条)  ← 已提交 issue #3421-#3424（已动态复现）
├── aiohttp/           (5 条)  ← 已提交 issue #13652-#13656（被关闭，已邮件跟进）
├── apkleaks/          (1 条)  ← 已发送邮件（CLI 版已补）
├── applio/            (7 条)  ← 已动态复现；FD-011 已提交私密 Advisory
├── archery/           (4 条)  ← 已动态复现（3 条 PoC 修正后含真实运行输出）
├── basicsr/           (2 条)  ← 已动态复现
├── ckan/              (1 条)  ← 已发送邮件
├── cognita/           (3 条)  ← 已动态复现（真实 HTTP 全链路）
├── cookiecutter/      (3 条)  ← 已提交私密 Advisory
├── dango-translator/  (5 条)  ← 已提交 issue #186-#190（复现证据整理自 issue，本次未重跑）
├── devika/            (7 条)  ← 已动态复现并按 skill 复核（05 runner 无沙箱判为加固已删）
├── drf/               (1 条)  ← 已动态复现
├── kohya_ss/          (2 条)  ← 已提交 issue #3603/#3604（已动态复现）
├── rasa/              (1 条)  ← 已动态复现（真实 HTTP 全链路；skill 判定降级为 Hardening）
├── stable-diffusion-webui/ (1 条) ← 已提交 issue #17492（复现证据整理自 issue，本次未重跑）
├── thefuck/           (3 条)  ← 已提交 issue #1621-#1623（已动态复现）
└── yt-dlp/            (1 条)  ← 已动态复现
```

## Open issue 对照（2026-09-23）

按目标仓库所有者 `REYu6` 的 `is:issue is:open author:REYu6` 查询，共 **14 个开放 issue、5 个项目**。本次补齐 6 份报告；另外 8 个 issue 已有对应报告，沿用现有文件。下表状态为查询时快照，开放状态不等于维护者确认，也不表示本次重新运行了 PoC。

| 项目 | 上游 issue | 对应报告 | 本次处理 |
| --- | --- | --- | --- |
| aim | [#3421](https://github.com/aimhubio/aim/issues/3421) | [客户端异常重建 RCE](aim/01-client-rce.md) | 已有 |
| aim | [#3422](https://github.com/aimhubio/aim/issues/3422) | [RPC 删除仓库](aim/02-repo-rm.md) | 已有 |
| aim | [#3423](https://github.com/aimhubio/aim/issues/3423) | [跨运行心跳清理](aim/03-heartbeat-cleanup.md) | 已有 |
| aim | [#3424](https://github.com/aimhubio/aim/issues/3424) | [touch 路径穿越](aim/04-touch-traversal.md) | 已有 |
| Dango-Translator | [#186](https://github.com/PantsuDango/Dango-Translator/issues/186) | [ChatGPT 密钥重定向](dango-translator/01-chatgpt-key-redirect.md) | 新增 |
| Dango-Translator | [#187](https://github.com/PantsuDango/Dango-Translator/issues/187) | [更新程序文件替换](dango-translator/02-update-executable-replacement.md) | 新增 |
| Dango-Translator | [#188](https://github.com/PantsuDango/Dango-Translator/issues/188) | [可逆保存密码](dango-translator/03-reversible-saved-password.md) | 新增 |
| Dango-Translator | [#189](https://github.com/PantsuDango/Dango-Translator/issues/189) | [OCR token 与图像外发](dango-translator/04-ocr-endpoint-token-image-leak.md) | 新增 |
| Dango-Translator | [#190](https://github.com/PantsuDango/Dango-Translator/issues/190) | [OCR 调试文件敏感数据残留](dango-translator/05-ocr-debug-secret-persistence.md) | 新增 |
| kohya_ss | [#3603](https://github.com/bmaltais/kohya_ss/issues/3603) | [HuggingFace token 日志泄露](kohya_ss/01-token-setup-log.md) | 已有 |
| stable-diffusion-webui | [#17492](https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/17492) | [内部路由遗漏 Gradio 认证](stable-diffusion-webui/01-gradio-auth-internal-routes.md) | 新增 |
| thefuck | [#1621](https://github.com/nvbn/thefuck/issues/1621) | [会话日志权限](thefuck/01-session-log-perms.md) | 已有 |
| thefuck | [#1622](https://github.com/nvbn/thefuck/issues/1622) | [日志投毒命令注入](thefuck/02-log-poison-cmd-inject.md) | 已有 |
| thefuck | [#1623](https://github.com/nvbn/thefuck/issues/1623) | [contrib 启用检查前执行](thefuck/03-contrib-pregate-exec.md) | 已有 |

新增报告保留来源 issue 的完整脚本与记录输出，并注明受影响快照、前提、修复建议及证据限制。Dango-Translator 更新问题仅记录惰性标记文件替换，未证明恶意 PE 执行；密码和调试文件问题以已有本地读取权限为前提。stable-diffusion-webui 报告注明已有相关上游报告，未将真实密钥或实时生成预览泄露写成已观察到的事实。

## 说明

- **2026-09-14 下架**：`autogpt(2) bazarr(4) django-sspanel(4) mindshub(9) nbviewer(2) odoo(2) rasa(1) twisted(1)` 共 25 份 CODE-VERIFIED（仅代码验证、未动态复现且未上报）的报告已从本仓库移除，待逐项按 skill 复核并动态复现后再视情况恢复。
- **2026-09-14 恢复 rasa(1)**：`01-callback-url-ssrf` 已用官方镜像 `rasa/rasa:3.6.21` 真实 HTTP 全链路复现（免鉴权 204 → 服务进程出站 POST 至仅内网可达目标，含对照组与盲探测证据）；按 skill 判定由「漏洞（SSRF + 数据外带）」降级为 **Security Hardening Suggestion**（回调为文档化特性、无跨用户数据、盲 POST 无响应回读）。
- 每份报告格式：

```
# <标题>
## Description   ← 漏洞描述（代码位置、机制）
## Impact        ← 影响（攻击者模型、边界、最坏后果）
## PoC           ← 复现命令/代码
## Execution result ← 实际执行输出
```
