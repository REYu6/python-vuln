# Postprocessing command injection via provider metadata

**Verification: CODE-VERIFIED**

## Description
`post_processing.py:L20-24`:
```python
# On Windows, use shell=True so cmd.exe handles backslashes
process = subprocess.Popen(command, shell=True, stderr=subprocess.PIPE, ...)
```
Provider-controlled metadata (release_info/uploader from subtitle provider) is embedded into the postprocessing command via naive quote-wrapping. Double-quotes in provider data break out of the quoting.

## Impact
Malicious subtitle provider site injects arbitrary commands into the postprocessing pipeline on Windows hosts (shell=True). On Unix, the impact is argument manipulation.

## PoC
```
Provider sets release_info or uploader to: x" & calc.exe & "
The double-quote breaks the naive wrapping; shell=True on Windows executes the injected command.
```

## Execution result
```
Code path analysis: post_processing.py:L24 — subprocess.Popen(command, shell=True)
with provider metadata embedded via naive quote concatenation.
```
