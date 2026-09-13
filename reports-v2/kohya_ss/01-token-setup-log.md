## Description

The HuggingFace token (and similar credentials) end up in plaintext in `setup.log` through the normal GUI initialization path, with no `--debug` flag and without the user saving anything:

1. `kohya_gui/class_huggingface.py` initializes the token textbox with `self.config.get("huggingface.token", "")`.
2. The generic `KohyaSSGUIConfig.get()` (`kohya_gui/class_gui_config.py`) ends with `log.debug(f"Returned {data}")` — no redaction of credential values.
3. `setup_logging()` (`kohya_gui/custom_logging.py`) configures the **root** logger at DEBUG level into `setup.log` (`logging.basicConfig(level=logging.DEBUG, filename="setup.log", ...)`), so the console's INFO level does not stop the file handler from recording these DEBUG lines.

Additionally the training tab prints the full TOML config (including `huggingface_token`, `wandb_api_key`) via `print_command_and_toml` → `log.info` (`kohya_gui/common_gui.py`), which also lands in `setup.log`; and `SaveConfigFile`'s exclusion list (`common_gui.py`) omits `huggingface_token`, so the token is persisted in plaintext config/TOML files as well.

## Impact

Anyone who can read `setup.log` or the GUI/training config files obtains the user's HuggingFace token (write access to private repos/orgs) — e.g. other accounts on a shared GPU server, log collection pipelines, or shared training outputs. The log channel is the least obvious one: just opening the GUI with a configured token leaks it to disk.

## PoC

Verified against the current kohya_ss GUI source (`kohya_gui` package) with a synthetic token `hf_fake_secret_TOKEN_9d8e7f6a5b4c` written into `config.toml`:

```toml
[huggingface]
token = "hf_fake_secret_TOKEN_9d8e7f6a5b4c"
```

```python
# real GUI init path

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)
from kohya_gui.custom_logging import setup_logging
setup_logging()                                  # root DEBUG -> setup.log
from kohya_gui.class_gui_config import KohyaSSGUIConfig
cfg = KohyaSSGUIConfig(config_file_path="./config.toml")
value = cfg.get("huggingface.token", "")         # HuggingFace tab init does exactly this
```

## Execution result

```
[victim] config.get returned token: hf_fake_secret_TOKEN_9d8e7f6a5b4c
[evidence] token found in setup.log: True
[evidence]   2026-09-07 23:03:24,192 | DEBUG | .../kohya_gui/class_gui_config.py | Returned hf_fake_secret_TOKEN_9d8e7f6a5b4c
[RESULT] {"poc": "kohya-01-hf-token-setup-log", "verdict": "REPRODUCED"}
```

`setup.log` contains the full token in cleartext after a plain GUI initialization — no `--debug`, no save action.
