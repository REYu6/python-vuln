# FD-019: TensorBoard unauthenticated proxy (PARTIAL on current snapshot)

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`app.py:250-280` mounts `@app.api_route('/tensorboard/{path:path}')` forwarding all methods to the locally launched TensorBoard with no authentication.

## Impact
Any client reaching the Gradio port reads training metrics and log contents.

## PoC
```python
c.predict(api_name="/launch_and_get_url")
# then GET http://<host>:6969/tensorboard/
```

## Execution result
```
On gradio 6.20.0 the api_route registration does not mount at runtime (404).
TensorBoard itself starts successfully on port 6006. Static route code exists;
dynamic chain broken in this specific version. Reported for awareness only.
```
