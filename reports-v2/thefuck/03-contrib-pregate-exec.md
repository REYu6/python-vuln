**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description

`corrector.get_rules_import_paths()` (`thefuck/corrector.py`) scans **every `sys.path` entry** for `thefuck_contrib_*` packages and yields their `rules/` directories. `Rule.from_path` (`thefuck/types.py`) then `load_source`'s (executes) each rule module **before** any `is_enabled` / settings gating is applied — the enabled-by-default functions in rules only run later, but the module top-level code has already executed at import time.

So any writable `sys.path` entry (a shared virtualenv, group-writable site-packages directory, or an attacker-planted `thefuck_contrib_*` package) results in code execution for every user who runs any thefuck command on that interpreter — regardless of their rules configuration.

## Impact

On shared multi-user machines (shared venvs, group-writable site-packages, or any scenario where a lower-privileged user can write into a `sys.path` entry used by another user's interpreter), a local user obtains code execution in every other user's thefuck invocation with that interpreter. On single-user machines this reduces to ordinary package-integrity trust and is not a boundary crossing — the report is about the shared-host case, and about the fact that the enable-gating documented in the rules system does not actually gate imports.

## PoC

Verified on thefuck 3.32 (source install). Drop a contrib package into the interpreter's site-packages (structure required by `get_rules_import_paths`):

```
site-packages/thefuck_contrib_evil/rules/evil.py:
    open('/tmp/thefuck_contrib_pwned', 'w').write('executed before enable-gating')
    def match(command):
        return False            # never matches; irrelevant — import already ran
```

Victim runs any correction:

```bash
thefuck "git statsu"
```

## Execution result

```
[evidence] contrib module side effect ran: True
[evidence] side-effect file content: executed before enable-gating
```

The module executed during rule loading, before any enable/disable decision could apply.

Suggested fix direction: defer `load_source` until after the rule's `is_enabled`/settings check, or restrict contrib discovery to explicitly configured paths.
