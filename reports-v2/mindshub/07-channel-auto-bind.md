# Channel sender auto-bind to default project

**Verification: CODE-VERIFIED**

## Description
Any sender passing signature verification is unconditionally auto-bound to default project with full agent privileges. Authentication conflated with authorization.

## Impact
Any user messaging the bot drives the full agent regardless of intended permission level.

## PoC
```
Send any message through a verified channel (Slack/Discord bot).
Platform auto-binds sender and executes agent with full privileges.
```

## Execution result
```
Code path analysis: channel handler auto-binds without checking project membership or role.
```
