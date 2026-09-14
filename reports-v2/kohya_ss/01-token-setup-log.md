# kohya_ss GUI: HuggingFace token written in cleartext to setup.log on plain initialization (no --debug, no save)

**Upstream issue:** https://github.com/bmaltais/kohya_ss/issues/3603

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04 against the real kohya_ss `kohya_gui` package; output below is from the actual run)

## Reproduction conditions

- kohya_ss GUI source (`kohya_gui` package, current `sd-scripts` GUI distribution), Ubuntu 24.04, Python 3.11
- A `config.toml` containing a HuggingFace token (as saved by the HuggingFace tab) — the token textbox initializes from it on every GUI start
- No `--debug` flag, no user interaction: just the GUI initialization path

## Description

The HuggingFace token ends up in plaintext in `setup.log` through the normal GUI initialization path:

1. `kohya_gui/class_huggingface.py` initializes the token textbox with `self.config.get("huggingface.token", "")`.
2. The generic `KohyaSSGUIConfig.get()` (`kohya_gui/class_gui_config.py:82`) ends with `log.debug(f"Returned {data}")` — no redaction of credential values.
3. `setup_logging()` (`kohya_gui/custom_logging.py`) configures the **root** logger at DEBUG level into `setup.log` (`logging.basicConfig(level=logging.DEBUG, filename="setup.log", ...)`), so the console's INFO level does not stop the file handler from recording these DEBUG lines.

Additionally the training tab prints the full TOML config (including `huggingface_token`, `wandb_api_key`) via `print_command_and_toml` → `log.info` (`kohya_gui/common_gui.py`), which also lands in `setup.log`; and `SaveConfigFile`'s exclusion list (`common_gui.py`) omits `huggingface_token`, so the token is persisted in plaintext config/TOML files as well.

## Impact

Anyone who can read `setup.log` or the GUI/training config files obtains the user's HuggingFace token (write access to private repos/orgs) — e.g. other accounts on a shared GPU server, log collection pipelines, or shared training outputs. The log channel is the least obvious one: just opening the GUI with a configured token leaks it to disk.

## PoC (copy-paste ready)

**Step 1 — victim has a token in `config.toml`** (as the HuggingFace tab saves it):

```toml
[huggingface]
token = "hf_fake_secret_TOKEN_9d8e7f6a5b4c"
```

**Step 2 — plain GUI initialization** (run from the kohya_ss directory):

```python
from kohya_gui.custom_logging import setup_logging
setup_logging()                                  # root DEBUG -> setup.log (what the GUI does at startup)

from kohya_gui.class_gui_config import KohyaSSGUIConfig
cfg = KohyaSSGUIConfig(config_file_path="./config.toml")
value = cfg.get("huggingface.token", "")         # HuggingFace tab init does exactly this
print(value)                                     # the value itself is expected — the leak is where it lands
```

**Step 3 — verify:**

```bash
grep hf_fake_secret setup.log
```

## Execution result (actual run: kohya_ss GUI source / Ubuntu 24.04 / Python 3.11)

```
=== Step 1: victim config.toml with a HF token (as saved by the HuggingFace tab) ===
token = "hf_fake_secret_TOKEN_9d8e7f6a5b4c"

=== Step 2: plain GUI initialization (no --debug, no save action) ===
[victim] config.get returned token: hf_fake_secret_TOKEN_9d8e7f6a5b4c

=== Step 3: check setup.log for the token ===
RESULT: REPRODUCED - token found in setup.log in cleartext:
2026-09-14 12:39:18,366 | DEBUG | .../kohya_gui/class_gui_config.py | Returned hf_fake_secret_TOKEN_9d8e7f6a5b4c
```

`setup.log` contains the full token in cleartext after a plain GUI initialization — no `--debug`, no save action.

## Suggested fix

Redact known credential keys (`huggingface.token`, `wandb_api_key`, …) before logging in `KohyaSSGUIConfig.get()`; drop the file handler to INFO; add `huggingface_token` to `SaveConfigFile`'s exclusion list.
