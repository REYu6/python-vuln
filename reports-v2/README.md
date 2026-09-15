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
├── devika/            (7 条)  ← 已动态复现并按 skill 复核（05 runner 无沙箱判为加固已删）
├── drf/               (1 条)  ← 已动态复现
├── kohya_ss/          (2 条)  ← 已提交 issue #3603/#3604（已动态复现）
├── rasa/              (1 条)  ← 已动态复现（真实 HTTP 全链路；skill 判定降级为 Hardening）
├── thefuck/           (3 条)  ← 已提交 issue #1621-#1623（已动态复现）
└── yt-dlp/            (1 条)  ← 已动态复现
```

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
