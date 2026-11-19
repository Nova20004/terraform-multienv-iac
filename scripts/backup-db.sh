#!/usr/bin/env bash
# pg_dump through the database container's local socket (the official image
# trusts local connections). Archives land in backups/<env>/, which is gitignored.
# Retention comes from the environment output backup_retention_days.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV="${ENV:-dev}"
TF="${TF:-terraform}"

case "${ENV}" in
  dev|staging|prod) ;;
  *)
    echo "ENV must be dev, staging or prod" >&2
    exit 1
    ;;
esac

env_dir="${ROOT}/environments/${ENV}"
container="$("${TF}" -chdir="${env_dir}" output -raw db_container_name)"
db_user="$("${TF}" -chdir="${env_dir}" output -raw db_username)"
db_name="$("${TF}" -chdir="${env_dir}" output -raw db_name)"
retention="$("${TF}" -chdir="${env_dir}" output -raw backup_retention_days)"

if ! [[ "${retention}" =~ ^[0-9]+$ ]] || [[ "${retention}" -lt 1 ]]; then
  echo "backup_retention_days must be a positive integer (got '${retention}')." >&2
  exit 1
fi

dest_dir="${ROOT}/backups/${ENV}"
mkdir -p "${dest_dir}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="${dest_dir}/${db_name}-${stamp}.sql.gz"

docker exec "${container}" pg_dump -U "${db_user}" -d "${db_name}" --no-password | gzip -c > "${archive}"
find "${dest_dir}" -type f -name '*.sql.gz' -mtime "+${retention}" -delete

echo "Wrote ${archive} (retention ${retention} days)."
