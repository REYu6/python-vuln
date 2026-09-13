# Gist raw file Content-Type from filename

**Verification: CODE-VERIFIED**

## Description
Gist handler (`nbviewer/providers/gist/handlers.py`) inherits from `RenderingHandler` which is based on the same base handler that sets `Content-Type: text/html` for raw files (base.py:450). Gist authors control both file bytes and the filename-derived Content-Type.

## Impact
Any gist author creates a file with HTML/SVG content -> served in nbviewer origin for any visitor who opens the link.

## PoC
```
1. Create a gist with payload.html (or .svg with embedded script)
2. Visit https://nbviewer.jupyter.org/gist/<user>/<gist_id>/payload.html
3. Script executes in nbviewer origin
```

## Execution result
```
Code path analysis: gist handler inherits RenderingHandler -> same
Content-Type:text/html mechanism as base.py:L450.
```
