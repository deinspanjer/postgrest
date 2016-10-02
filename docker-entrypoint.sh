#!/bin/bash

read -d '' usage << EOF
$(<postgrest_usage.txt)
  -q,--quiet               Do not log the options used

The following environment variables can be used to construct the DB_URL instead of passing it as an argument.

Environment variables:
  PG_ENV_POSTGRES_USER
  PG_ENV_POSTGRES_PASSWORD
  PG_PORT_5432_TCP_ADDR
  PG_PORT_5432_TCP_PORT
  PG_ENV_POSTGRES_DB

The format of the resulting DB_URL will be:
  postgres://\${PG_ENV_POSTGRES_USER}:\${PG_ENV_POSTGRES_PASSWORD}@\${PG_PORT_5432_TCP_ADDR}:\${PG_PORT_5432_TCP_PORT}/\${PG_ENV_POSTGRES_DB}
EOF

LOG_OPTIONS=1
OPTS=$(getopt -o hqa:x:s:l:p:j:o:m: --long help,quiet,anonymous:,proxy-uri:,schema:,host:,port:,jwt-secret:,pool:,max-rows: -n 'postgrest' -- "$@") || { echo "$usage" && exit 1; }
eval set -- "$OPTS"
while true; do
    case "$1" in
    -h|--help)
        echo "$usage"; exit 1;;
    -q|--quiet)
        LOG_OPTIONS=0
        shift;;
    -a|--anonymous)
        ROLE="$2"
        shift 2;;
    -x|--proxy-uri)
        PROXY="$2"
        shift 2;;
    -s|--schema)
        NAME="$2"
        shift 2;;
    -l|--host)
        HOST="$2"
        shift 2;;
    -p|--port)
        echo "PORT argument is ignored when running in Docker. Map port 3000 using the container engine."
        shift 2;;
    -j|--jwt-secret)
        SECRET="$2"
        shift 2;;
    -o|--pool)
        POOL="$2"
        shift 2;;
    -m|--max-rows)
        COUNT="$2"
        shift 2;;
    --) shift; break;;
    *)  echo $usage; exit 1;;
    esac
done

if [ -z "$ROLE" ]; then
    echo "Anonymous ROLE option must be supplied.$usage"
    exit 1
fi

if [[ $# == 0 ]]; then
    if [ -z "$PG_PORT_5432_TCP_ADDR" ]; then
        echo "One of DB_URL option or environment variable PG_PORT_5432_TCP_ADDR must be specified.$usage"
        exit 1
    fi
    DB_URL="postgres://${PG_ENV_POSTGRES_USER:=postgres}${PG_ENV_POSTGRES_PASSWORD:+:}${PG_ENV_POSTGRES_PASSWORD}@${PG_PORT_5432_TCP_ADDR}${PG_PORT_5432_TCP_PORT:+:}${PG_PORT_5432_TCP_PORT}/${PG_ENV_POSTGRES_DB:=postgres}"
elif [[ $# == 1 ]]; then
    DB_URL=$1
    shift
else
    echo $usage
    exit 1;
fi

[ $LOG_OPTIONS ] && cat << EOF
postgrest started with these options:

DB_URL=${DB_URL/:*@/:<password>@}

ROLE=${ROLE}
PROXY=${PROXY-"<not set>"}
NAME=${NAME-"<not set> (default: 'public')"}
HOST=${HOST-"<not set> (default: '*4')"}
PORT=3000 (Required value for Docker container)
SECRET=$(if [ -z "$SECRET" ]; then echo "<not set> (default: 'secret')"; else echo "<secret>"; fi)
POOL=${POOL-"<not set> (default: 10)"}
COUNT=${COUNT-"<not set> (default: 'infinity')"}

EOF

exec postgrest $DB_URL \
            --anonymous ${ROLE} \
            ${PROXY+"--proxy-uri"} ${PROXY} \
            ${NAME+"--schema"} ${NAME} \
            ${HOST+"--host"} ${HOST} \
            --port 3000 \
            ${SECRET+"--jwt-secret"} ${SECRET} \
            ${POOL+"--pool"} ${POOL} \
            ${COUNT+"--max-rows"} ${COUNT}
