## Description

`shell_logger` (`thefuck/entrypoints/shell_logger.py`) creates the session transcript log with no mode argument:

```python
fd = os.open(output, os.O_CREAT | os.O_TRUNC | os.O_RDWR)   # mode defaults to 0o777 & ~umask
```

Under the default umask 022 this produces a **0755** log file (even the execute bit leaks in); under umask 002 (common on Ubuntu with private groups) it is 0664 group-writable; under umask 000 it is fully 0777. The log is the 1 MiB mmap buffer into which the whole pty session stream (everything echoed to the terminal, including instant-mode sessions started via the generated shell alias) is written for the lifetime of the session. There is no `chmod`, `mkdtemp`, or `O_EXCL` anywhere in the path.

## Impact

On a shared multi-user machine, any local user can read another user's full session transcript (commands, outputs, and anything echoed to the terminal) while it is being written. With umask 000 / group-writable setups the same file is writable by others, which also enables the log-poisoning chain (steering proposed corrected commands — happy to file that separately if useful).

## PoC

Verified on thefuck 3.32 (source install, Ubuntu 24.04):

```bash
$ umask 022
$ thefuck -l /tmp/demo.log < /dev/null      # creates the 1 MiB transcript mmap log
$ stat -c "%a %s" /tmp/demo.log
755 1048576

# as a second local user:

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)
$ su attacker -c "head -c 16 /tmp/demo.log"; echo "rc=$?"
00000000: 0000 0000 ...                      rc=0
```

## Execution result

```
umask 022 -> log mode 755 (world-readable AND world-executable), size 1048576
attacker@host read of the transcript: exit 0
umask 000 -> mode 777 (verified separately)
```

A one-line fix would be passing an explicit mode, e.g. `os.open(output, os.O_CREAT | os.O_TRUNC | os.O_RDWR, 0o600)`.
