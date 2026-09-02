#!/usr/bin/env bash
# Start (or initialize) the project-local PostgreSQL cluster used for this analysis.
# Binds to 127.0.0.1:55432 so it does not collide with a system Postgres on 5432.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/Library/PostgreSQL/18/bin:${PATH}"

PGDATA="${ROOT}/.local/pgdata"
PGSOCK="${ROOT}/.local"
PGPORT="${PGPORT:-55432}"
PGUSER="${PGUSER:-marketplace}"
PGDATABASE="${PGDATABASE:-marketplace_ops}"

if ! command -v initdb >/dev/null || ! command -v pg_ctl >/dev/null; then
  echo "PostgreSQL client/server binaries not found. Add psql/initdb/pg_ctl to PATH."
  echo "This project was developed with /Library/PostgreSQL/18/bin."
  exit 1
fi

mkdir -p "${PGSOCK}"

if [[ ! -f "${PGDATA}/PG_VERSION" ]]; then
  initdb -D "${PGDATA}" --encoding=UTF8 --locale=en_US.UTF-8 \
    --auth-local=trust --auth-host=trust -U "${PGUSER}"
fi

if ! pg_isready -h 127.0.0.1 -p "${PGPORT}" >/dev/null 2>&1; then
  pg_ctl -D "${PGDATA}" -l "${ROOT}/.local/postgres.log" \
    -o "-p ${PGPORT} -k ${PGSOCK} -h 127.0.0.1" start
fi

pg_isready -h 127.0.0.1 -p "${PGPORT}"

if ! psql -h 127.0.0.1 -p "${PGPORT}" -U "${PGUSER}" -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${PGDATABASE}'" | grep -q 1; then
  psql -h 127.0.0.1 -p "${PGPORT}" -U "${PGUSER}" -d postgres \
    -c "CREATE DATABASE ${PGDATABASE};"
fi

echo "PostgreSQL ready: postgresql://${PGUSER}@127.0.0.1:${PGPORT}/${PGDATABASE}"
