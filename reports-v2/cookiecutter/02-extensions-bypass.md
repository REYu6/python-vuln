# Report 2 of 3: Template `_extensions` are imported and executed even with `--accept-hooks=no` (hook-awareness bypass, explicitly in SECURITY.md scope)

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

- Affected version: cookiecutter 2.7.1 (current main, source install)
- SECURITY.md lists "Hook execution awareness bypass (mechanisms that cause hooks to run without the user's knowledge)" as in scope — this is that case for the `_extensions` surface.

## Description

`accept_hooks` gating (`cli.py` / `main.py`) only wraps hook script execution (`pre_prompt`, `pre_gen_project`, `post_gen_project`). Template Jinja2 extensions declared in `cookiecutter.json` are imported on **every** generation path during `StrictEnvironment` construction (`cookiecutter/environment.py`, `ExtensionLoaderMixin.__init__`), with the template repository directory temporarily inserted into `sys.path` (`main.py`) so template-shipped modules load:

```json
{"_extensions": ["evil_ext.EvilExtension"], "name": "x"}
```

`evil_ext.py` (shipped inside the template) runs its module top-level code at import time.

## Impact

A user who explicitly opts out of executing template code (`cookiecutter <tpl> --accept-hooks=no`, or `accept_hooks: False` in the config) still gets template-author code executed — the consent mechanism does not cover this surface. Anyone reviewing a template for "does it have hooks I should worry about" will miss `_extensions`, which is exactly the awareness gap the SECURITY.md scope item describes.

## PoC

Verified on cookiecutter 2.7.1. Template layout:

```
evil/
  cookiecutter.json    -> {"_extensions": ["evil_ext.EvilExtension"], "name": "x"}
  evil_ext.py          -> import jinja2
                           open('/tmp/cc_fd007_extension_pwned', 'w').write('extension imported ... outside accept_hooks gate')
                           class EvilExtension(jinja2.ext.Extension): ...
  {{cookiecutter.name}}.txt
```

Victim generates with hooks explicitly declined:

```bash
cookiecutter ./evil --no-input --accept-hooks=no -o ./out
```

## Execution result

```
[FD-007] template extension code executed despite --accept-hooks=no: True
[FD-007] side-effect file content: extension imported BEFORE/OUTSIDE accept_hooks gate
```

`/tmp/cc_fd007_extension_pwned` exists after the run — module top-level code ran although the user declined hook execution.

Suggested fix direction: apply the same `accept_hooks` gate to `_extensions` loading (either skip extension imports entirely when hooks are declined, or at minimum warn the user that the template requests code-executing extensions).
