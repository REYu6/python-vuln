# Binlog endpoints without resource-group filter

**Verification: CODE-VERIFIED**

## Description
Three binlog endpoints parse instances without `user_instances` filtering:
- `my2sql` extracts binlog row data for other groups' instances
- `del_binlog` deletes other groups' binlog files
- Instance resolution does not check group membership

## Impact
Authenticated user with binlog menu permission reads cross-group row data (bypassing masking/query permissions) and destroys other groups' point-in-time recovery.

## PoC
```bash
curl "http://<host>/binlog/list/?instance_id=<other_group_instance>"
```

## Execution result
```
Code path analysis: binlog endpoints resolve instances without
user_instances/group filtering.
```
