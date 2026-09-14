# Archery: offline export writes unmasked data while online queries are masked

**Verification: DYNAMICALLY-REPRODUCED** (both paths executed through the product's own service functions on a live instance; output below is from the actual run)

## Reproduction conditions

- Archery source (current main era snapshot), Django 5.0, Python 3.13, WSL2 Ubuntu 24.04; MySQL 8 + Redis 7 + native goInception (the masking analyzer) — the goInception token service is part of Archery's documented masking setup
- Data masking **enabled** (`SysConfig data_masking=1`, the documented deployment option); masking rule on `phone` (`(1[0-9]{2})[0-9]{4}([0-9]{4})`, hide group 2) registered on `DataMaskingRules`, column bound via `DataMaskingColumns` (instance/schema/table/column)
- User `victimB` holds a table query privilege on `sensitive_users` (priv_type=2)
- Both paths were invoked through the product's real functions (`sqlquery_service.execute_sql_query`, `OffLineDownLoad.execute_offline_download`) in a `manage.py shell` — the same functions the HTTP flow dispatches to; the offline function is the one the async worker calls

## Description

The online query path applies masking: `sqlquery_service.execute_sql_query` runs `query_engine.query(...)` and then, when `data_masking` is enabled, `query_engine.query_masking(...)` (`sql/services/sqlquery_service.py:108-110`), which resolves the result columns through goInception and masks values matching `DataMaskingRules`.

The offline export path contains **no masking anywhere**: `OffLineDownLoad.execute_offline_download` (`sql/offlinedownload.py:70-158`) executes `check_engine.query(...)`, writes `results.rows` straight into `save_to_format_file(...)`, and the downloadable archive holds the raw values.

## Impact

Any user with export permission obtains the sensitive columns (phone numbers, IDs, whatever the masking rules protect) as **plaintext** in the downloaded file, while the same query executed online shows masked values — the platform's data masking security feature is bypassed on the whole offline-export path. Combined with the `downloadfile/` IDOR (companion finding), even users without export permission can download other users' unmasked exports.

## PoC (the two real paths, same SQL, same user)

```python
# victimB, table privilege granted, masking enabled — one SQL, two product paths:
SQL = "select id, phone from sensitive_users"

# path A — ONLINE (what /query/ dispatches to):
from sql.services.sqlquery_service import execute_sql_query
res = execute_sql_query(user=victim, instance_name="victim-mysql",
                        db_name="archery_src", sql_content=SQL, limit_num=100)

# path B — OFFLINE EXPORT (what the async worker calls):
from sql.offlinedownload import OffLineDownLoad
out = OffLineDownLoad(instance=inst).execute_offline_download(workflow)
# -> writes downloads/DataExportFile/<name>.zip containing <name>.csv
```

## Execution result (actual run)

```
=== path A: ONLINE query service (masking applied) ===
status: 0 | msg: ok
columns: ['id', 'phone']
rows: [[1, '138****'], [2, '139****']]
MASKED in online result: True
RAW in online result: False

=== path B: OFFLINE export (execute_offline_download) ===
export file: downloads/DataExportFile/archery_src_20260914180407_6dcea37c.zip
--- inner csv ---
"id","phone"
"1","13812345678"
"2","13987654321"
RAW phone in offline export: True
MASKED in offline export: False
```

Same SQL, same user, same instance: the online path returns masked values; the exported file contains the plaintext phone numbers.

## Suggested fix

Apply the same masking step in the export path: after `check_engine.query(...)` in `execute_offline_download`, run `check_engine.query_masking(...)` (respecting `data_masking` config and failing closed when `query_check` is set) before `save_to_format_file`.
