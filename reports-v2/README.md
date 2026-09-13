# 漏洞报告总索引 — reports-v2

62 个审计项目 × 技能五因子复核 → 21 个项目 69 个漏洞实锤，每项目一目录、每漏洞一文件。

## 目录结构

```
reports-v2/
├── README.md          ← 本索引
├── aim/               (4 条)  ← 已提交 issue #3421-#3424
├── aiohttp/           (5 条)  ← 已提交 issue #13652-#13656（被关闭，已邮件跟进）
├── apkleaks/          (1 条)  ← 已发送邮件（CLI 版已补）
├── applio/            (7 条)  ← 待提交（私密 Advisory）
├── archery/           (4 条)  ← 待提交（私密 Advisory）
├── autogpt/           (2 条)  ← 待提交（私密 Advisory）
├── basicsr/           (2 条)  ← 待提交（公开 issue）
├── bazarr/            (4 条)  ← 待提交（私密 Advisory）
├── ckan/              (1 条)  ← 已发送邮件
├── cognita/           (3 条)  ← 仓库已归档，不可提交
├── cookiecutter/      (3 条)  ← 已提交私密 Advisory
├── devika/            (8 条)  ← 待提交（公开 issue）
├── django-sspanel/    (4 条)  ← 仓库已归档，不可提交
├── kohya_ss/          (2 条)  ← 已提交 issue #3603/#3604
├── mindshub/          (9 条)  ← 待提交（邮件 hello@mindsdb.com）
├── nbviewer/          (2 条)  ← 待提交（公开 issue）
├── odoo/              (2 条)  ← 待提交（官网表单）
├── rasa/              (1 条)  ← 待提交（公开 issue）
├── thefuck/           (3 条)  ← 已提交 issue #1621-#1623
├── twisted/           (1 条)  ← 待提交（私密 Advisory）
└── yt-dlp/            (1 条)  ← 待提交（私密 Advisory）
```

## 按提交状态汇总

| 状态 | 项目数 | 漏洞数 |
|---|---|---|
| **已提交** | 8 | 16 |
| **待提交** | 11 | 42 |
| **不可提交**（归档） | 2 | 7 |
| **未复现有 STRONG** | 15 | ~22 |
| **无 STRONG** | 26 | 0 |
| **合计** | **62** | — |

## 按渠道分组的待提交清单

| 渠道 | 项目 | 文件数 |
|---|---|---|
| **私密 Advisory** | applio(7) bazarr(4) twisted(1) yt-dlp(1) autogpt(2) archery(4) | 19 |
| **邮件** | mindshub → hello@mindsdb.com (9) | 9 |
| **公开 issue** | devika(8) nbviewer(2) basicsr(2) rasa(1) | 13 |
| **官网表单** | odoo → odoo.com/security-report (2) | 2 |

## 每份报告格式

```
# <标题>
## Description   ← 漏洞描述（代码位置、机制）
## Impact        ← 影响（攻击者模型、边界、最坏后果）
## PoC           ← 复现命令/代码
## Execution result ← 实际执行输出
```
