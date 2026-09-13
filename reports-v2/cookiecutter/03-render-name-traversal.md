# Report 3 of 3 (boundary case, submitted for triage): rendered file/dir names containing `..` are written outside the project output directory

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

- Affected version: cookiecutter 2.7.1 (current main, source install)
- I am aware the Trust Model places template authors outside the trust boundary for malicious content; I am submitting this because the rendered output landing **outside the expected output directory** seems adjacent to the in-scope item "Template rendering exfiltration (vulnerabilities in the Jinja2 layer that leak data outside the expected output)". Happy to withdraw if you consider it covered by the trust model.

## Description

`generate.py` (`generate_file` / `generate_files` / `render_and_create_dir`) joins rendered names into the output path without any containment check:

```python
os.path.join(project_dir, rendered_name)      # rendered_name may contain '..' or be absolute
```

A template variable used inside a file or directory name (from `cookiecutter.json` defaults, raw prompt answers, `extra_context`, replay files, or `default_context` config) can therefore place rendered files outside the generated project directory.

## Impact

A template (cloned or zipped, third-party or attacker-crafted) can write chosen content to paths outside the output directory the user selected — e.g. overwrite dotfiles in the directory above the output location. The user's review of "what will be generated where" is based on the output directory argument; this escapes it.

## PoC

Template with a name-bearing variable defaulting to a traversal value:

```
evil/
  cookiecutter.json                     -> {"escape": "../../ESCAPED_FILE_FD004"}
  {{cookiecutter.escape}}.txt           -> written outside the project dir
```

```bash
cookiecutter ./evil --no-input -o ./sandbox/out/gen
```

## Execution result

```
[FD-004] escaped file created outside project dir: True
        marker: <sandbox>/ESCAPED_FILE_FD004.txt   (output dir was <sandbox>/out/gen/evil)
```

The rendered file landed two levels above the requested output directory.

Suggested fix direction: after rendering, verify each target path is contained under the project directory (`os.path.commonpath` check) and raise on traversal or absolute components.
