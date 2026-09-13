# Concurrent balance write without lock

**Verification: CODE-VERIFIED**

## Description
Balance modifications in `apps/sspanel/` use `.save()` without `select_for_update()` or `F()` expressions. The default docker-compose includes celery beat (15s reconciliation task) as a cross-process writer.

## Impact
On default deployment: paid orders can be lost or double-deduction occurs = free goods. The celery beat reconciliation task races with web-request balance updates.

## PoC
```
Two concurrent purchase requests for the same account:
1. Both read balance=10
2. Both deduct 5 (writing balance=5)
3. Result: balance=5 instead of 0 (one deduction lost)
```

## Execution result
```
Code path analysis: balance .save() calls without select_for_update
or F() expressions; celery beat acts as concurrent writer.
```
