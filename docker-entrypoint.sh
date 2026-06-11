#!/usr/bin/env bash
set -Eeo pipefail
# Hardened, adapted for:
# - custom Postgres install under /opt/postgres (adjust PATH if needed)
# - PGDATA=/var/lib/postgresql/$PG_MAJOR/data
# - container starts as root, drops to UID 65532 via gosu

# --- environment / paths ------------------------------------------------------

# Adjust this to match your actual install prefix
export PATH="/opt/postgres/bin:$PATH"

# usage: file_env VAR [DEFAULT]
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        printf >&2 'error: both %s and %s are set (but are exclusive)\n' "$var" "$fileVar"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

_is_sourced() {
    [ "${#FUNCNAME[@]}" -ge 2 ] \
        && [ "${FUNCNAME[0]}" = '_is_sourced' ] \
        && [ "${FUNCNAME[1]}" = 'source' ]
}

# --- directory / ownership setup ---------------------------------------------

docker_create_db_directories() {
    local user; user="$(id -u)"

    mkdir -p "$PGDATA"
    chmod 00700 "$PGDATA" || :

    mkdir -p /var/run/postgresql || :
    chmod 03775 /var/run/postgresql || :

    if [ -n "${POSTGRES_INITDB_WALDIR:-}" ]; then
        mkdir -p "$POSTGRES_INITDB_WALDIR"
        if [ "$user" = '0' ]; then
            # hardened: chown to UID 65532
            find "$POSTGRES_INITDB_WALDIR" \! -uid 65532 -exec chown 65532:65532 '{}' +
        fi
        chmod 700 "$POSTGRES_INITDB_WALDIR"
    fi

    if [ "$user" = '0' ]; then
        find "$PGDATA" \! -uid 65532 -exec chown 65532:65532 '{}' +
        find /var/run/postgresql \! -uid 65532 -exec chown 65532:65532 '{}' +
    fi
}

# --- initdb -------------------------------------------------------------------

docker_init_database_dir() {
    # nss_wrapper removed for hardened image; assume proper /etc/passwd entry

    if [ -n "${POSTGRES_INITDB_WALDIR:-}" ]; then
        set -- --waldir "$POSTGRES_INITDB_WALDIR" "$@"
    fi

    eval 'initdb --username="$POSTGRES_USER" --pwfile=<(printf "%s\n" "$POSTGRES_PASSWORD") '"$POSTGRES_INITDB_ARGS"' "$@"'
}

# --- env verification ---------------------------------------------------------

docker_verify_minimum_env() {
    if [ -z "$POSTGRES_PASSWORD" ] && [ 'trust' != "$POSTGRES_HOST_AUTH_METHOD" ]; then
        cat >&2 <<-'EOE'
            Error: Database is uninitialized and superuser password is not specified.
                   You must specify POSTGRES_PASSWORD to a non-empty value for the
                   superuser. For example, "-e POSTGRES_PASSWORD=password" on "docker run".

                   You may also use "POSTGRES_HOST_AUTH_METHOD=trust" to allow all
                   connections without a password. This is *not* recommended.

                   See PostgreSQL documentation about "trust":
                   https://www.postgresql.org/docs/current/auth-trust.html
        EOE
        exit 1
    fi
    if [ 'trust' = "$POSTGRES_HOST_AUTH_METHOD" ]; then
        cat >&2 <<-'EOWARN'
            ********************************************************************************
            WARNING: POSTGRES_HOST_AUTH_METHOD has been set to "trust". This will allow
                     anyone with access to the Postgres port to access your database without
                     a password, even if POSTGRES_PASSWORD is set. See PostgreSQL
                     documentation about "trust":
                     https://www.postgresql.org/docs/current/auth-trust.html
                     In Docker's default configuration, this is effectively any other
                     container on the same system.

                     It is not recommended to use POSTGRES_HOST_AUTH_METHOD=trust. Replace
                     it with "-e POSTGRES_PASSWORD=password" instead to set a password in
                     "docker run".
            ********************************************************************************
        EOWARN
    fi
}

docker_error_old_databases() {
    if [ -n "${OLD_DATABASES[0]:-}" ]; then
        cat >&2 <<-EOE
            Error: in 18+, these Docker images are configured to store database data in a
                   format which is compatible with "pg_ctlcluster" (specifically, using
                   major-version-specific directory names).  This better reflects how
                   PostgreSQL itself works, and how upgrades are to be performed.

                   See also https://github.com/docker-library/postgres/pull/1259

                   Counter to that, there appears to be PostgreSQL data in:
                     ${OLD_DATABASES[*]}

                   This is usually the result of upgrading the Docker image without
                   upgrading the underlying database using "pg_upgrade" (which requires both
                   versions).

                   The suggested container configuration for 18+ is to place a single mount
                   at /var/lib/postgresql which will then place PostgreSQL data in a
                   subdirectory, allowing usage of "pg_upgrade --link" without mount point
                   boundary issues.

                   See https://github.com/docker-library/postgres/issues/37 for a (long)
                   discussion around this process, and suggestions for how to do so.
        EOE
        exit 1
    fi
}

# --- init scripts -------------------------------------------------------------

docker_process_init_files() {
    psql=( docker_process_sql )

    printf '\n'
    local f
    for f; do
        case "$f" in
            *.sh)
                if [ -x "$f" ]; then
                    printf '%s: running %s\n' "$0" "$f"
                    "$f"
                else
                    printf '%s: sourcing %s\n' "$0" "$f"
                    . "$f"
                fi
                ;;
            *.sql)     printf '%s: running %s\n' "$0" "$f"; docker_process_sql -f "$f"; printf '\n' ;;
            *.sql.gz)  printf '%s: running %s\n' "$0" "$f"; gunzip -c "$f" | docker_process_sql; printf '\n' ;;
            *.sql.xz)  printf '%s: running %s\n' "$0" "$f"; xzcat "$f" | docker_process_sql; printf '\n' ;;
            *.sql.zst) printf '%s: running %s\n' "$0" "$f"; zstd -dc "$f" | docker_process_sql; printf '\n' ;;
            *)         printf '%s: ignoring %s\n' "$0" "$f" ;;
        esac
        printf '\n'
    done
}

docker_process_sql() {
    local query_runner=( psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --no-password --no-psqlrc )
    if [ -n "$POSTGRES_DB" ]; then
        query_runner+=( --dbname "$POSTGRES_DB" )
    fi

    PGHOST= PGHOSTADDR= "${query_runner[@]}" "$@"
}

docker_setup_db() {
    local dbAlreadyExists
    dbAlreadyExists="$(
        POSTGRES_DB= docker_process_sql --dbname postgres --set db="$POSTGRES_DB" --tuples-only <<-'EOSQL'
            SELECT 1 FROM pg_database WHERE datname = :'db' ;
        EOSQL
    )"
    if [ -z "$dbAlreadyExists" ]; then
        POSTGRES_DB= docker_process_sql --dbname postgres --set db="$POSTGRES_DB" <<-'EOSQL'
            CREATE DATABASE :"db" ;
        EOSQL
        printf '\n'
    fi
}

# --- env setup / PGDATA layout -----------------------------------------------

docker_setup_env() {
    file_env 'POSTGRES_PASSWORD'

    file_env 'POSTGRES_USER' 'postgres'
    file_env 'POSTGRES_DB' "$POSTGRES_USER"
    file_env 'POSTGRES_INITDB_ARGS'
    : "${POSTGRES_HOST_AUTH_METHOD:=}"

    declare -g DATABASE_ALREADY_EXISTS
    : "${DATABASE_ALREADY_EXISTS:=}"
    declare -ag OLD_DATABASES=()

    if [ -s "$PGDATA/PG_VERSION" ]; then
        DATABASE_ALREADY_EXISTS='true'
    elif [ "$PGDATA" = "/var/lib/postgresql/$PG_MAJOR/data" ]; then
        for d in /var/lib/postgresql /var/lib/postgresql/data /var/lib/postgresql/*/data; do
            if [ -s "$d/PG_VERSION" ]; then
                OLD_DATABASES+=( "$d" )
            fi
        done
        if [ "${#OLD_DATABASES[@]}" -eq 0 ] && [ "$PG_MAJOR" -ge 18 ] && {
            mountpoint -q /var/lib/postgresql/data \
            || awk '$5 == "/var/lib/postgresql/data" { found = 1 } END { exit !found }' /proc/self/mountinfo
        }; then
            OLD_DATABASES+=( '/var/lib/postgresql/data (unused mount/volume)' )
        fi
    fi
}

pg_setup_hba_conf() {
    if [ "$1" = 'postgres' ]; then
        shift
    fi
    local auth
    auth="$(postgres -C password_encryption "$@")"
    : "${POSTGRES_HOST_AUTH_METHOD:=$auth}"
    {
        printf '\n'
        if [ 'trust' = "$POSTGRES_HOST_AUTH_METHOD" ]; then
            printf '# warning trust is enabled for all connections\n'
            printf '# see https://www.postgresql.org/docs/17/auth-trust.html\n'
        fi
        printf 'host all all all %s\n' "$POSTGRES_HOST_AUTH_METHOD"
    } >> "$PGDATA/pg_hba.conf"
}

docker_temp_server_start() {
    if [ "$1" = 'postgres' ]; then
        shift
    fi

    set -- "$@" -c listen_addresses='' -p "${PGPORT:-5432}"

    NOTIFY_SOCKET= \
    PGUSER="${PGUSER:-$POSTGRES_USER}" \
    pg_ctl -D "$PGDATA" \
        -o "$(printf '%q ' "$@")" \
        -w start
}

docker_temp_server_stop() {
    PGUSER="${PGUSER:-postgres}" \
    pg_ctl -D "$PGDATA" -m fast -w stop
}

_pg_want_help() {
    local arg
    for arg; do
        case "$arg" in
            -'?'|--help|--describe-config|-V|--version)
                return 0
                ;;
        esac
    done
    return 1
}

_main() {
    # if first arg looks like a flag, assume we want to run postgres server
    if [ "${1:0:1}" = '-' ]; then
        set -- postgres "$@"
    fi

    if [ "$1" = 'postgres' ] && ! _pg_want_help "$@"; then
        docker_setup_env
        docker_create_db_directories

        if [ "$(id -u)" = '0' ]; then
            # hardened: do setup as root, then drop to UID 65532 via gosu
            exec gosu 65532:65532 "$BASH_SOURCE" "$@"
        fi

        if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
            docker_verify_minimum_env
            docker_error_old_databases

            ls /docker-entrypoint-initdb.d/ > /dev/null

            docker_init_database_dir
            pg_setup_hba_conf "$@"

            export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
            docker_temp_server_start "$@"

            docker_setup_db
            docker_process_init_files /docker-entrypoint-initdb.d/*

            docker_temp_server_stop
            unset PGPASSWORD

            cat <<-'EOM'

                PostgreSQL init process complete; ready for start up.

            EOM
        else
            cat <<-'EOM'

                PostgreSQL Database directory appears to contain a database; Skipping initialization

            EOM
        fi
    fi

    exec "$@"
}

if ! _is_sourced; then
    _main "$@"
fi

