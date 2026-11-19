# database

One Postgres 17 container on the internal backend network.

- No `ports` block. The host cannot reach it through a published port.
- Password comes from `random_password` (alphanumeric, 32 characters) and is a sensitive output. It is not written into the Ansible inventory.
- Data lives on a named volume. `scripts/backup-db.sh` runs `pg_dump` inside the container and deletes archives older than `backup_retention_days`.
- A healthcheck blocks apply until `pg_isready` succeeds.

This is not a highly available database. There is one container, one volume and no replica.
