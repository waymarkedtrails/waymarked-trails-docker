#!/bin/sh

NGINX_PID_DIR=/run/nginx
NGINX_CERT_DIR=/etc/nginx
DB=${DBNAME:-planet}
DATA=${DATAFILE:-data.osm.pbf}
JOBS=${JOBS:-4}
WMT_CONFIG=${WMT_CONFIG:-hiking}

i=1
MAXCOUNT=60
echo "> Waiting for PostgreSQL database to be running"
while [ $i -le $MAXCOUNT ]
do
  pg_isready -q && echo "> PostgreSQL database running" && break
  sleep 2
  i=$((i+1))
done
test $i -gt $MAXCOUNT && echo "> Timeout while waiting for PostgreSQL to be running"

# check if the database DBNAME (DB falls back to planet if not) exists
# if not we import data
if ! psql -lqt | cut -d \| -f 1 | grep -qw $DB; then
    if [ -f "/import/$DATA" ]; then
        echo
        echo "> Importing data into $DB."

        cd /waymarkedtrails
        # DATA = DATAFILE || data.osm.pbf
        python3 makedb.py -j $JOBS -f /import/$DATA db import
        python3 makedb.py db prepare

        cd  /tmp
        curl -s http://www.nominatim.org/data/country_grid.sql.gz > country_grid.sql.gz

        zcat country_grid.sql.gz | psql -d $DB && \
            psql -d $DB -c "ALTER TABLE country_osm_grid ADD COLUMN geom geometry(Geometry,3857)" && \
            psql -d $DB -c "UPDATE country_osm_grid SET geom=ST_Transform(geometry, 3857)" && \
            psql -d $DB -c "ALTER TABLE country_osm_grid DROP COLUMN geometry" && \
        rm -f country_grid.sql.gz

        cd /waymarkedtrails
        python3 makedb.py $WMT_CONFIG create
        python3 makedb.py $WMT_CONFIG import
    else
        echo
        echo "> Data file $DATA missing. Cannot import data."
    fi
fi

# initialize nginx pid directory
if [ ! -d $NGINX_PID_DIR ]; then
  mkdir -p $NGINX_PID_DIR
  chown -R nginx:nginx $NGINX_PID_DIR
fi

# generate TLS certificate if not exists and NOCERT variable is not set
if [ ! -f "$NGINX_CERT_DIR/key.pem" ] && [ ! -n "$NOCERT" ]; then
    echo
    echo "> Create nginX TLS certificate"
    openssl req -newkey rsa:2048 -x509 -keyout "$NGINX_CERT_DIR/key.pem" -out "$NGINX_CERT_DIR/server.pem" \
        -subj "/C=CTRY/ST=STE/L=/O=Org/OU=/CN=localhost/" -days 3650 -nodes
fi

# generate DH parameters if not exist and NODH variable is not set
if [ ! -f "$NGINX_CERT_DIR/dh2048.pem" ] && [ ! -n "$NODH" ]; then
    echo
    echo "> Generate Diffie-Hellman parameters"
    openssl dhparam -out "$NGINX_CERT_DIR/dh2048.pem" 2048
fi

# start S6 init process and give it any parameters that might got in
# as docker command
exec env WMT_CONFIG=$WMT_CONFIG /init $@
