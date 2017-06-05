#!/bin/bash
# 50-config.py or equivalent must be run first to set omero.db.*

set -eu

omero=/opt/omero/server/OMERO.server/bin/omero
cd /opt/omero/server

CONFIG_omero_db_host=${CONFIG_omero_db_host:-}
if [ -n "$CONFIG_omero_db_host" ]; then
    DBHOST="$CONFIG_omero_db_host"
else
    DBHOST=db
    $omero config set omero.db.host "$DBHOST"
fi
DBUSER="${CONFIG_omero_db_user:-omero}"
DBNAME="${CONFIG_omero_db_name:-omero}"
DBPASS="${CONFIG_omero_db_pass:-omero}"
ROOTPASS="${ROOTPASS:-omero}"

export PGPASSWORD="$DBPASS"

i=0
while ! psql -h "$DBHOST" -U "$DBUSER" "$DBNAME" >/dev/null 2>&1 < /dev/null; do
    i=$(($i+1))
    if [ $i -ge 50 ]; then
        echo "$(date) - postgres:5432 still not reachable, giving up"
        exit 1
    fi
    echo "$(date) - waiting for postgres:5432..."
    sleep 1
done
echo "postgres connection established"

psql -w -h "$DBHOST" -U "$DBUSER" "$DBNAME" -c \
    "select * from dbpatch" 2> /dev/null && {
    echo "Upgrading database"
    DBCMD=upgrade
} || {
    echo "Initialising database"
    DBCMD=init
}
/opt/omero/omego/bin/omego db $DBCMD \
    --dbhost "$DBHOST" --dbuser "$DBUSER" --dbname "$DBNAME" \
    --dbpass "$DBPASS" --rootpass "$ROOTPASS" --serverdir=OMERO.server
