#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "postgres" ]; then
  if [ ! -s "$PGDATA/PG_VERSION" ]; then
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$(dirname "$PGDATA")"
    chmod 0700 "$PGDATA"

    gosu postgres initdb -D "$PGDATA"

    # Optionally: drop in custom configs here later
    # e.g. cp /etc/postgresql/postgresql.conf "$PGDATA"/
    #      cp /etc/postgresql/pg_hba.conf "$PGDATA"/
  fi

  exec gosu postgres postgres -D "$PGDATA"
fi

exec "$@"
