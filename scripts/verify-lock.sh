#!/usr/bin/env bash
# Non-destructive lock check.
# 1. Two plans in the same environment: exactly one must fail to acquire the lock.
# 2. One plan in dev and one plan in staging: both must succeed.
# Do not run this from CI: it needs the state database and a real Docker daemon.
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

conn_for() {
  printf 'postgres://%s:%s@%s:%s/terraform_state_%s?sslmode=%s' \
    "${STATE_DB_USER}" \
    "${TF_VAR_state_db_password}" \
    "${STATE_DB_HOST}" \
    "${STATE_DB_PORT}" \
    "$1" \
    "${STATE_DB_SSLMODE}"
}

if [[ -z "${TF_VAR_ssh_public_key:-}" && -f "${ROOT}/.ssh/id_ed25519.pub" ]]; then
  TF_VAR_ssh_public_key="$(tr -d '\n' < "${ROOT}/.ssh/id_ed25519.pub")"
  export TF_VAR_ssh_public_key
fi

if [[ -z "${DOCKER_HOST:-}" ]]; then
  detected="$(docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)"
  if [[ -n "${detected}" ]]; then
    export DOCKER_HOST="${detected}"
  fi
fi

lock_re='already locked|Error acquiring the state lock'
cleanup_files=()
cleanup() {
  if ((${#cleanup_files[@]})); then
    rm -f "${cleanup_files[@]}"
  fi
}
trap cleanup EXIT

init_env() {
  local env="$1"
  local dir="${ROOT}/environments/${env}"
  if [[ ! -f "${dir}/backend.hcl" ]]; then
    cp "${dir}/backend.hcl.example" "${dir}/backend.hcl"
  fi
  PG_CONN_STR="$(conn_for "${env}")" \
    "${TF}" -chdir="${dir}" init -input=false -reconfigure -backend-config=backend.hcl >/dev/null
}

start_plan() {
  local env="$1"
  local log="$2"
  local plan="$3"
  cleanup_files+=("${log}" "${plan}")
  (
    cd "${ROOT}/environments/${env}"
    PG_CONN_STR="$(conn_for "${env}")" \
      "${TF}" plan -input=false -lock-timeout=0s -out="${plan}"
  ) >"${log}" 2>&1 &
}

echo "== same environment (${ENV}) =="
init_env "${ENV}"
log_a="$(mktemp)"
log_b="$(mktemp)"
start_plan "${ENV}" "${log_a}" "${ROOT}/environments/${ENV}/tfplan.verify-a"
pid_a="$!"
start_plan "${ENV}" "${log_b}" "${ROOT}/environments/${ENV}/tfplan.verify-b"
pid_b="$!"
status_a=0
status_b=0
wait "${pid_a}" || status_a=$?
wait "${pid_b}" || status_b=$?

hits=0
oks=0
for pair in "a:${status_a}:${log_a}" "b:${status_b}:${log_b}"; do
  name="${pair%%:*}"
  rest="${pair#*:}"
  code="${rest%%:*}"
  log="${rest#*:}"
  if [[ "${code}" -eq 0 ]]; then
    oks=$((oks + 1))
    echo "plan ${name}: exit 0"
  elif grep -Eqi "${lock_re}" "${log}"; then
    hits=$((hits + 1))
    echo "plan ${name}: blocked by the state lock (exit ${code})"
  else
    echo "plan ${name}: failed for a reason other than the state lock (exit ${code})" >&2
    cat "${log}" >&2
    exit 1
  fi
done

if [[ "${oks}" -ne 1 || "${hits}" -ne 1 ]]; then
  echo "FAIL: expected one successful plan and one lock error in ${ENV} (got ${oks} success, ${hits} lock errors)." >&2
  exit 1
fi
echo "PASS: two plans in ${ENV} conflict. The second was rejected."

echo "== dev and staging concurrently =="
init_env dev
init_env staging
log_dev="$(mktemp)"
log_staging="$(mktemp)"
start_plan dev "${log_dev}" "${ROOT}/environments/dev/tfplan.verify-cross"
pid_dev="$!"
start_plan staging "${log_staging}" "${ROOT}/environments/staging/tfplan.verify-cross"
pid_staging="$!"
status_dev=0
status_staging=0
wait "${pid_dev}" || status_dev=$?
wait "${pid_staging}" || status_staging=$?

if [[ "${status_dev}" -ne 0 || "${status_staging}" -ne 0 ]]; then
  echo "FAIL: a dev plan and a staging plan should both run (dev exit ${status_dev}, staging exit ${status_staging})." >&2
  echo "----- dev -----" >&2
  cat "${log_dev}" >&2
  echo "----- staging -----" >&2
  cat "${log_staging}" >&2
  exit 1
fi

if grep -Eqi "${lock_re}" "${log_dev}" "${log_staging}"; then
  echo "FAIL: dev and staging blocked each other." >&2
  exit 1
fi

echo "PASS: a plan in dev and a plan in staging ran together without blocking."
