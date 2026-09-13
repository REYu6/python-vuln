# jsonrpc routes unconditionally return full tracebacks

**Verification: CODE-VERIFIED**

## Description
http.py:469 serialize_exception captures full traceback; called at :2617/:2678. dev_mode gate explicitly excludes jsonrpc routes.

## Impact
Anonymous remote gets full tracebacks: paths, versions, internal structure, DB queries.

## PoC
```bash
curl -X POST http://<odoo>/jsonrpc/1/ -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"call","params":{"service":"nonexistent","method":"x"}}'
```

## Execution result
```
Code path analysis: serialize_exception unconditional; dev_mode excludes jsonrpc.
```
