## Description

In instant mode (`THEFUCK_INSTANT_MODE=true`), the corrected-command proposal is built from the session output log (`THEFUCK_OUTPUT_LOG`), and output-derived tokens are concatenated into the proposal **without shell quoting**. Combined with two weaknesses this yields a command-injection chain from a poisoned log:

1. `output_readers/read_log.py::_get_script_group_lines` selects the log group for a command with a loose substring match (`all(part in script_line for part in parts)`) over the whole shared log;
2. many rules extract tokens from `command.output` and insert them into the new command unquoted — e.g. `rules/brew_install.py` regex-extracts the `Did you mean X` suggestion and returns `"brew install " + formula`;
3. `CorrectedCommand.run` writes the proposal to stdout, and the shell alias evaluates that stdout — so anything in the proposal is executed as shell code (with `--yes`, without even a confirmation prompt).

## Impact

Anyone who can write to the session log (a second local user when the log is group/world-writable — see the separate report on the 0755/0777 default modes; or any process compromise) gets arbitrary command execution in the victim's shell session when the victim next runs thefuck on a matching failed command. Example: the poisoned log line `Did you mean evil; touch /tmp/pwned?` produces the proposal `brew install evil; touch /tmp/pwned`, which the alias evaluates verbatim.

## PoC

Verified on thefuck 3.32 (source install). The log is poisoned with the same structure `read_log` expects (a `\u200b*10`-marked script line followed by "output" lines, padded to the 1 MiB mmap size):

```python
MARK = "\u200b" * 10
lines = [f"{MARK}brew install foo\n",
         'Warning: No available formula with the name "foo". Did you mean evil; touch /tmp/thefuck_pwned_REC?\n',
         f"{MARK}$ \n"]
# ... pad to 1048576 bytes like shell_logger does

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)
```

Victim side (a `brew` shim on PATH simulates a brew-equipped machine):

```bash
THEFUCK_OUTPUT_LOG=/tmp/thefuck_poisoned.log THEFUCK_INSTANT_MODE=true \
PS1=$MARK'$ ' thefuck --yes "brew install foo"
```

## Execution result

```
[victim] thefuck stdout (what the shell alias evals):
brew install evil; touch /tmp/thefuck_pwned_REC
[evidence] proposal contains injected payload: True
[evidence] payload command executed after alias-style eval: True   # /tmp/thefuck_pwned_REC created
```

The proposal steered by the poisoned log was written to stdout and, evaluated exactly as the alias does, executed the injected command.

Suggested fix directions: quote output-derived tokens when composing proposals (`shlex.quote`), and/or tighten the log-group match beyond substring containment.
