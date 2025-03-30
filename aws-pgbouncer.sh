AWS_REGION=${AWS_REGION:-"us-east-1"}
DB_NAME=${DB_NAME:-"postgres"}
DB_HOST=${DB_HOST:-"localhost"}
DB_PORT=${DB_PORT:-"5432"}
DB_USERNAME=${DB_USERNAME:-"postgres"}
PGBOUNCER_LISTEN_PORT=${PGBOUNCER_LISTEN_PORT:-"5432"}
PGBOUNCER_LISTEN_ADDR=${PGBOUNCER_LISTEN_ADDR:-"*"}
TMP_DIR=${TMP_DIR:-"/tmp"}
CONF_DIR=${CONF_DIR:-"/etc"}

write_pgbouncer_ini() {
  if [ ! -f "$TMP_DIR"/pgbouncer-aws-secret ]; then
    echo "No secret file found. Exiting..."
    exit 1
  fi
  local PASSWORD
  PASSWORD=$(cat "$TMP_DIR"/pgbouncer-aws-secret)
  mkdir -p "$CONF_DIR"/pgbouncer
  cat <<EOF >"$CONF_DIR"/pgbouncer/pgbouncer.ini
[databases]
${DB_NAME} = host=${RDS_HOST} port=${DB_PORT} dbname=${DB_NAME} user=${DB_USERNAME} password=${PASSWORD}

[pgbouncer]
listen_port = ${PGBOUNCER_LISTEN_PORT}
listen_addr = ${PGBOUNCER_LISTEN_ADDR}
auth_type = any
admin_users = app_admin
pool_mode = transaction
max_client_conn = 100
default_pool_size = 20
server_tls_sslmode = require
min_pool_size = 0
reserve_pool_size = 0
server_lifetime = 604800
# some Java libraries set this extra_float_digits implicitly: https://github.com/Athou/commafeed/issues/559
ignore_startup_parameters = extra_float_digits
EOF
}

get_secret_version() {
  aws rds generate-db-auth-token --hostname "$RDS_HOST" --port "$DB_PORT" --region "$AWS_REGION" --username "$DB_USERNAME" >"$TMP_DIR"/pgbouncer-aws-secret
}

PGBOUNCER_PID=
MONITOR_PID=

monitor_pgbouncer() {
  PARENT_PID=$1
  PGBOUNCER_PID=$2
  echo "Monitoring pgbouncer... (parent PID: ${PARENT_PID}, pgbouncer PID: ${PGBOUNCER_PID})"
  trap "exit 0" SIGTERM SIGINT
  while true; do
    if ! is_pgbouncer_running; then
      echo "pgbouncer is not running. Exiting..."
      kill -s 2 "${PARENT_PID}"
      exit 1
    fi
    sleep 1 &
    wait $!
  done
}

is_pgbouncer_running() {
  if [ -n "${PGBOUNCER_PID}" ]; then
    if ps -p "${PGBOUNCER_PID}" >/dev/null; then
      return 0
    fi
  fi
  return 1
}

start_pgbouncer() {
  if is_pgbouncer_running; then
    echo "Reloading pgbouncer..."
    pkill -HUP pgbouncer
  else
    echo "Starting pgbouncer..."
    pgbouncer -R "$CONF_DIR"/pgbouncer/pgbouncer.ini &
    PGBOUNCER_PID=$!
    echo "pgbouncer started with PID ${PGBOUNCER_PID}"
    monitor_pgbouncer $$ $PGBOUNCER_PID &
    MONITOR_PID=$!
  fi
}

shut_down() {
  if ps -p ${MONITOR_PID} >/dev/null; then
    echo "Stopping monitor..."
    kill -s 2 ${MONITOR_PID} || true
  fi
  if ps -p ${PGBOUNCER_PID} >/dev/null; then
    echo "Stopping pgbouncer..."
    kill -s 2 ${PGBOUNCER_PID} || true
    wait ${PGBOUNCER_PID} >/dev/null 2>&1 || true
  fi
  exit 0
}

trap shut_down SIGTERM SIGINT

get_secret_version
write_pgbouncer_ini
start_pgbouncer
wait $PGBOUNCER_PID
