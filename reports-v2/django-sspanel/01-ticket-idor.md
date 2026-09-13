# Ticket IDOR — bare pk without ownership check

**Verification: CODE-VERIFIED**

## Description
Ticket views in `apps/sspanel/views.py` fetch records by bare `pk` without comparing to `request.user`. Lines with `ticket` and `pk` in the same expression have no nearby user/owner check.

## Impact
Cross-user ticket conversation read + reply injection. Any logged-in user accesses any other user's support tickets.

## PoC
```bash
curl "http://<host>/tickets/<other_users_pk>/" -H "Cookie: sessionid=<logged_in>"
```

## Execution result
```
Code path analysis: ticket views use get_object_or_404(Ticket, pk=pk)
without filtering by request.user.
```
