#!/bin/bash

# === Configuration à adapter ===

# WebLogic Home
MW_HOME="/u01/oracle/middleware"

# Chemin de tes fichiers sécurisés
USERCONFIGFILE="/chemin/secureConfigFile"
USERKEYFILE="/chemin/secureKeyFile"

# Infos Node Manager
NM_HOST="localhost"
NM_PORT="5556"
DOMAIN_NAME="base_domain"
DOMAIN_HOME="/u01/domains/base_domain"

# WLST
WLST="$MW_HOME/oracle_common/common/bin/wlst.sh"

# === Fin de la configuration ===

usage() {
  echo "Utilisation: $0 {start|stop|status} {ManagedServerName|ALL}"
  exit 1
}

ACTION=$1
SERVER=$2

if [ -z "$ACTION" ] || [ -z "$SERVER" ]; then
  usage
fi

$WLST <<EOF
nmConnect(userConfigFile='$USERCONFIGFILE', userKeyFile='$USERKEYFILE', host='$NM_HOST', port='$NM_PORT', domainName='$DOMAIN_NAME', domainDir='$DOMAIN_HOME')

if '$SERVER' == 'ALL':
    servers = nmServerStatus()
    server_list = servers.split('\n')
    for s in server_list:
        name = s.split(' ')[0]
        if '$ACTION' == 'start':
            nmStart(name)
        elif '$ACTION' == 'stop':
            nmKill(name)
        elif '$ACTION' == 'status':
            nmServerStatus(name)
        else:
            print('Action inconnue : ' + '$ACTION')
else:
    if '$ACTION' == 'start':
        nmStart('$SERVER')
    elif '$ACTION' == 'stop':
        nmKill('$SERVER')
    elif '$ACTION' == 'status':
        nmServerStatus('$SERVER')
    else:
        print('Action inconnue : ' + '$ACTION')

nmDisconnect()
EOF
