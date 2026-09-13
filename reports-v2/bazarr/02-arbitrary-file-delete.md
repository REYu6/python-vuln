# Arbitrary file deletion via extension-gated os.remove

**Verification: CODE-VERIFIED**

## Description
Multiple os.remove calls in bazarr operate on paths with only extension checks:
- `utilities/cache.py:L30`: `os.remove(path)` on subtitle cache
- `utilities/backup.py:L254`: `os.remove(backup_file_path)`
- `subtitles/gemini_translator.py:L200`: `os.remove(self.progress_file)`

No media-directory containment check on any delete path.

## Impact
API-accessible deletion of arbitrary subtitle-extension files outside the media library.

## PoC
```bash
curl -X DELETE "http://<host>:6767/api/subtitles?path=/home/user/important.srt&apikey=<key>"
```

## Execution result
```
Code path analysis: os.remove at cache.py:L30, backup.py:L254, gemini_translator.py:L200
with no directory boundary check.
```
