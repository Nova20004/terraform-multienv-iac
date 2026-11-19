#!/usr/bin/env bash
# Proves the application database publishes no host port, is not reachable
# from the host, and is reachable from a node on the backend network.
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

if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi

if [[ -z "${TF_VAR_state_db_password:-}" ]]; then
  echo "TF_VAR_state_db_password is not set. Run make env first." >&2
  exit 1
fi

STATE_DB_USER="${STATE_DB_USER:-terraform}"
STATE_DB_HOST="${STATE_DB_HOST:-127.0.0.1}"
STATE_DB_PORT="${STATE_DB_PORT:-55432}"
STATE_DB_SSLMODE="${STATE_DB_SSLMODE:-disable}"
# Same rule as the Makefile: the database name follows ENV, even if .env
# still contains a sample URL for one environment.
PG_CONN_STR="$(printf 'postgres://%s:%s@%s:%s/terraform_state_%s?sslmode=%s' \
  "${STATE_DB_USER}" \
  "${TF_VAR_state_db_password}" \
  "${STATE_DB_HOST}" \
  "${STATE_DB_PORT}" \
  "${ENV}" \
  "${STATE_DB_SSLMODE}")"
export PG_CONN_STR

env_dir="${ROOT}/environments/${ENV}"
db="$("${TF}" -chdir="${env_dir}" output -raw db_container_name)"
db_user="$("${TF}" -chdir="${env_dir}" output -raw db_username)"
db_name="$("${TF}" -chdir="${env_dir}" output -raw db_name)"
node="$(
  "${TF}" -chdir="${env_dir}" output -json node_container_names \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)[0])'
)"

echo "database container: ${db}"
echo "node container: ${node}"

bindings="$(docker inspect -f '{{json .HostConfig.PortBindings}}' "${db}")"
if [[ "${bindings}" != "{}" && "${bindings}" != "null" && "${bindings}" != "map[]" ]]; then
  echo "FAIL: ${db} publishes host ports: ${bindings}" >&2
  exit 1
fi
echo "PASS: ${db} has no published host ports."

# Exit 0 when the TCP connection fails, 1 when it succeeds.
unreachable() {
  python3 - "$1" "$2" <<'PY'
import socket, sys
host, port = sys.argv[1], int(sys.argv[2])
sock = socket.socket()
sock.settimeout(3)
try:
    sock.connect((host, port))
except OSError:
    sys.exit(0)
sys.exit(1)
PY
}

if unreachable 127.0.0.1 5432; then
  echo "PASS: 127.0.0.1:5432 is not accepting connections."
else
  echo "FAIL: something on the host accepts TCP 5432." >&2
  exit 1
fi

db_ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "${db}" | awk '{print $1}')"
if [[ -z "${db_ip}" ]]; then
  echo "FAIL: could not read an IP address for ${db}" >&2
  exit 1
fi

if unreachable "${db_ip}" 5432; then
  echo "PASS: the host cannot open TCP ${db_ip}:5432."
else
  echo "FAIL: the host reached the database at ${db_ip}:5432. The backend network is not isolated from this Docker host." >&2
  exit 1
fi

if docker exec "${node}" python3 -c 'import socket,sys; socket.create_connection((sys.argv[1], 5432), 5).close()' "${db}"; then
  echo "PASS: ${node} opened TCP 5432 on ${db} over the backend network."
else
  echo "FAIL: ${node} could not reach ${db}:5432" >&2
  exit 1
fi

# `docker exec cmd -v` is parsed as a docker flag. Run the test inside a shell.
if docker exec "${node}" sh -c 'command -v pg_isready >/dev/null 2>&1'; then
  docker exec "${node}" pg_isready -h "${db}" -p 5432 -U "${db_user}" -d "${db_name}"
  echo "PASS: pg_isready from ${node} accepted ${db}."
else
  echo "SKIPPED: pg_isready is not installed on ${node} yet. TCP from the node succeeded."
fi
