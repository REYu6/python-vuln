# Offline export bypasses masking entirely

**Verification: CODE-VERIFIED**

## Description
The offline export execution path has no `query_masking`/`query_priv_check` calls anywhere in the code. Sensitive columns that are masked in online query results are written as plaintext to downloadable files.

## Impact
The platform's data masking security feature is bypassed across the entire offline export path. Users with export permission see raw sensitive data that would normally be masked.

## PoC
```bash
# Trigger an offline export for a query that would normally be masked:
curl -X POST "http://<host>/query/export/" \
  -H "Cookie: sessionid=<session>" \
  -d "sql=SELECT phone,ssn FROM sensitive_table&export_type=offline"
# Download the file (see /downloadfile/ finding) - contains unmasked data
```

## Execution result
```
Code path analysis: offline export code path contains zero calls to
query_masking or query_priv_check.
```
