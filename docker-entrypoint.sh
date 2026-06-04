#!/bin/bash
set -e

if [ "$1" = "postgres" ]; then
    if [ ! -s "$PGDATA/PG_VERSION" ]; then
        echo "Initializing database cluster at $PGDATA"
        mkdir -p "$PGDATA"
        chown -R postgres:postgres "$PGDATA"
        chmod 700 "$PGDATA"

        gosu postgres initdb -D "$PGDATA"
    fi

    exec gosu postgres postgres -D "$PGDATA"
fi

exec "$@"
