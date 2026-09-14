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
├── devika/            (8 条)  ← 已动态复现
├── drf/               (1 条)  ← 已动态复现
├── kohya_ss/          (2 条)  ← 已提交 issue #3603/#3604（已动态复现）
├── thefuck/           (3 条)  ← 已提交 issue #1621-#1623（已动态复现）
└── yt-dlp/            (1 条)  ← 已动态复现
```

## 说明

- **2026-09-14 下架**：`autogpt(2) bazarr(4) django-sspanel(4) mindshub(9) nbviewer(2) odoo(2) rasa(1) twisted(1)` 共 25 份 CODE-VERIFIED（仅代码验证、未动态复现且未上报）的报告已从本仓库移除，待逐项按 skill 复核并动态复现后再视情况恢复。
- 每份报告格式：

```
# <标题>
## Description   ← 漏洞描述（代码位置、机制）
## Impact        ← 影响（攻击者模型、边界、最坏后果）
## PoC           ← 复现命令/代码
## Execution result ← 实际执行输出
```
