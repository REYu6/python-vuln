# F-H-MSGRENDER-1 + F-H-LOGRENDER-1: Stored XSS via {@html} rendering

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`MessageContainer.svelte:62-73` renders via `bind:innerHTML` and `{@html}`. Logs page `+page.svelte:46-58` renders through `{@html log}`. DOMPurify sanitizes only outbound composer input, not stored/inbound content.

## Impact
Attacker or model-echoed markup → stored XSS in any client viewing messages/logs.

## PoC
```python
mgr.add_message_from_user("xss-victim", "<img src=x onerror=alert(1)>")
# then: POST /api/messages {"project_name": "xss-victim"} → reflected verbatim
```

## Execution result
```
[RENDER] {"stored_and_returned_raw": true,
          "frontend_sinks": {"message": "MessageContainer.svelte:62-73",
                              "log": "+page.svelte:46-58"}}
```
