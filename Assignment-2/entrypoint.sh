#!/bin/bash
set -e

PGDATA="/usr/local/pgsql/data"
PGBIN="/usr/local/pgsql/bin"
SQLDIR="/usr/local/pgsql/sql"

# The data directory is pre-initialized in the Docker image.
# This fallback handles the case where an empty volume is mounted over $PGDATA.
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Data directory is empty — re-initializing from image defaults..."
    "$PGBIN/initdb" -D "$PGDATA" --auth-local=trust --auth-host=trust -U postgres
    echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
    echo "host all all 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf"
    "$PGBIN/pg_ctl" -D "$PGDATA" -l "$PGDATA/logfile" start
    until "$PGBIN/pg_isready" -U postgres -q; do sleep 0.5; done
    "$PGBIN/createdb" university
    "$PGBIN/psql" -d university -f "$SQLDIR/DDL.sql"
    "$PGBIN/psql" -d university -f "$SQLDIR/smallRelationsInsertFile.sql"
    "$PGBIN/pg_ctl" -D "$PGDATA" stop
fi

# Start PostgreSQL
echo "Starting PostgreSQL..."
"$PGBIN/pg_ctl" -D "$PGDATA" -l "$PGDATA/logfile" start

until "$PGBIN/pg_isready" -U postgres -q; do
    sleep 0.5
done

echo "PostgreSQL is ready. Connect with:  psql -U postgres -d university"

# Drop into a shell or run the provided command
if [ "$#" -eq 0 ]; then
    exec /bin/bash
else
    exec "$@"
fi
