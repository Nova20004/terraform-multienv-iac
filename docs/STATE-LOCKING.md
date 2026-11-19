# State locking

Bootstrap (`bootstrap/`) is a one-time root with local state. It starts Postgres 17, publishes `127.0.0.1:55432` only, and mounts `bootstrap/initdb/01-create-state-databases.sql` into the image entrypoint directory. That script creates three databases:

| Environment | Database |
|---|---|
| dev | `terraform_state_dev` |
| staging | `terraform_state_staging` |
| prod | `terraform_state_prod` |

The script runs only when the data volume is empty. Changing it later does nothing until the volume is recreated.

Each environment uses a partial `backend "pg" {}`. `make` builds `PG_CONN_STR` from `.env` (`STATE_DB_USER`, `STATE_DB_HOST`, `STATE_DB_PORT`, `STATE_DB_SSLMODE`, and `TF_VAR_state_db_password`) and appends the database for `ENV`. The password is not written into `backend.hcl`. `backend.hcl.example` sets no keys. `make init` copies it and runs `terraform init -reconfigure -backend-config=backend.hcl`.

`sslmode=disable` is acceptable only for this loopback container. A Postgres server on another host should use `sslmode=require` or `verify-full`.

Concurrent Terraform operations in the same database are serialized by Postgres advisory locks. The lock belongs to that database session and disappears when the session ends. This backend does not support `terraform force-unlock`. A lock held by another session cannot be stolen.

```bash
make locks ENV=dev
```

That reads `pg_locks` in `terraform_state_dev`. Use `ENV=staging` or `ENV=prod` for the other databases.

Because each environment has its own database, a plan in dev and a plan in staging do not block each other. Two plans in the same environment do. `scripts/verify-lock.sh` checks both, and it is not part of CI.

State contains the generated application database password. The Ansible inventory does not. The state container is bound to loopback. Treat a dump of that volume as a secret.
