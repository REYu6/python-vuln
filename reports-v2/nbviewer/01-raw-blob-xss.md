# Raw non-notebook blob served as text/html

**Verification: CODE-VERIFIED**

## Description
`nbviewer/providers/base.py:450`:
```python
self.set_header("Content-Type", "text/html")
```
`base.py:461`:
```python
for key in ("Content-Type",):
    # upstream headers forwarded
```
Non-notebook files accessed via the raw/GitHub URL are served as text/html in the nbviewer origin. The CSP only restricts connect-src, not inline script execution.

## Impact
Any GitHub repo author publishes a non-ipynb file (HTML/SVG with embedded script) -> any visitor to the nbviewer URL gets attacker script executed in the nbviewer origin. Session/data theft from nbviewer's authenticated context.

## PoC
```
1. Create GitHub repo with file payload.html containing <script>alert(document.domain)</script>
2. Visit https://nbviewer.jupyter.org/github/<user>/<repo>/blob/main/payload.html
3. Script executes in nbviewer origin
```

## Execution result
```
Code path analysis: base.py:L450 sets Content-Type:text/html for raw files;
L461 forwards upstream headers; CSP does not restrict script-src.
```
