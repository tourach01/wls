#!/bin/bash

# === Configuration à adapter ===
MW_HOME="/u01/oracle/middleware"
DOMAIN_HOME="/u01/domains/base_domain"
DOMAIN_NAME="base_domain"
ADMIN_HOST="localhost"
ADMIN_PORT="7001"
NM_HOST="localhost"
NM_PORT="5556"
NM_SECURE_FILES_DIR="/u01/secure"
WLST="$MW_HOME/oracle_common/common/bin/wlst.sh"
JAVA_HOME="/usr/java/latest"
PROCESS_CHECK_DELAY=5  # secondes avant vérification du kill
# === Fin Configuration ===

ACTION=$1
SERVER=$2

usage() {
  echo "Usage: $0 {start|stop|status} {ManagedServer|ALL}"
  exit 1
}

[ -z "$ACTION" ] || [ -z "$SERVER" ] && usage

# Liste dynamique des Managed Servers (hors AdminServer)
get_managed_servers() {
  find "$DOMAIN_HOME/servers" -maxdepth 1 -mindepth 1 -type d \
    -exec basename {} \; | grep -v "^AdminServer$"
}

# Test de disponibilité de l'Admin Server
admin_available() {
  nc -z -w 3 $ADMIN_HOST $ADMIN_PORT &>/dev/null
}

# Test existence fichiers sécurisés Node Manager
nm_secure_files_exist() {
  [ -f "$NM_SECURE_FILES_DIR/nmUserConfig" ] && [ -f "$NM_SECURE_FILES_DIR/nmUserKey" ]
}

# Identification du PID d'un ManagedServer
get_pid() {
  local server_name="$1"
  ps -eo pid,cmd --cols=5000 | \
    grep -E "[j]ava.*weblogic\.Server.*weblogic\.Name=${server_name}" | \
    awk '{print $1}'
}
 

# Arrêt propre puis brutal d'un serveur par PID
kill_server_process() {
  PID=$(get_pid "$1")
  if [ -n "$PID" ]; then
    echo "Stopping $1 (PID $PID)..."
    kill "$PID"
    sleep $PROCESS_CHECK_DELAY
    if kill -0 "$PID" &>/dev/null; then
      echo "Process still running, forcing kill -9..."
      kill -9 "$PID"
    else
      echo "$1 stopped gracefully."
    fi
  else
    echo "No running process found for $1."
  fi
}

# Vérification du statut via PID
status_server_process() {
  PID=$(get_pid "$1")
  if [ -n "$PID" ]; then
    echo "$1:RUNNING (PID $PID)"
  else
    echo "$1:SHUTDOWN"
  fi
}

# Préparation exécution WLST simplifiée
run_wlst() {
  export JAVA_OPTIONS="-Dweblogic.wlstQuiet=true"
  $WLST "$@" 2>/dev/null | grep "^RESULT:" | sed 's/^RESULT://'
}

# Méthode via Admin Server (WLST)
method_admin() {
  run_wlst <<EOF
connect()
servers=['$1'] if '$1' != 'ALL' else [s.getName() for s in cmo.getServers() if s.getName() != 'AdminServer']
for srv in servers:
  state=state(srv, 'Server')
  print("RESULT:{}:{}".format(srv, state))
  if '$ACTION'=='start' and state!='RUNNING':
    start(srv,'Server')
  elif '$ACTION'=='stop' and state=='RUNNING':
    shutdown(srv,'Server','true',30000)
disconnect()
EOF
}

# Méthode via Node Manager (WLST)
method_nm() {
  run_wlst <<EOF
nmConnect(userConfigFile='$NM_SECURE_FILES_DIR/nmUserConfig', userKeyFile='$NM_SECURE_FILES_DIR/nmUserKey', host='$NM_HOST', port='$NM_PORT', domainName='$DOMAIN_NAME', domainDir='$DOMAIN_HOME')
servers=['$1'] if '$1' != 'ALL' else "$(get_managed_servers)"
for srv in servers.split():
  try:
    status=nmServerStatus(srv)
  except:
    status='UNKNOWN'
  print("RESULT:{}:{}".format(srv, status))
  if '$ACTION'=='start' and status!='RUNNING':
    nmStart(srv)
  elif '$ACTION'=='stop' and status=='RUNNING':
    nmKill(srv)
nmDisconnect()
EOF
}

# Méthode via Process (fallback)
method_process() {
  servers=("$1")
  [ "$1" == "ALL" ] && readarray -t servers <<< "$(get_managed_servers)"
  for srv in "${servers[@]}"; do
    case $ACTION in
      status)
        status_server_process "$srv"
        ;;
      stop)
        kill_server_process "$srv"
        ;;
      start)
        echo "Cannot start $srv without AdminServer or NodeManager."
        ;;
    esac
  done
}

# === MAIN LOGIC ===
if admin_available; then
  echo "[*] Using AdminServer method."
  method_admin "$SERVER"
elif nm_secure_files_exist; then
  echo "[*] Admin unavailable. Using NodeManager method."
  method_nm "$SERVER"
else
  echo "[*] Admin and NodeManager unavailable. Using direct process management."
  method_process "$SERVER"
fi
