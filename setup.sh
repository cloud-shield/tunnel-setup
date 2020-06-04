#!/bin/bash

###################################################################################
##
## Cloud-Shield Linux/BSD install script for Tunnel Configurator
## Version: 1.0
## https://github.com/cloud-shield/tunnel-setup
##
## https://cloud-shield.ru
## support@cloud-shield.ru
##
###################################################################################


# cstunnel.sh
TUN_SH_URL="https://raw.githubusercontent.com/cloud-shield/tunnel-setup/master/cstunnel.sh"
TUN_SH_PATH="/usr/local/bin/cstunnel"
# systemd
SYSD_URL="https://raw.githubusercontent.com/cloud-shield/tunnel-setup/master/cstunnel.service"
SYSD_PATH="/etc/systemd/system/cstunnel.service"


function install {
    if [ -z "$2" ]; then
        echo "Key is empty. Please provide a secret key"
        echo "Usage: $0 install (up|down|debug)"
        exit 1
    fi

    # dependencies
    echo -n 'Checking dependencies...' >&2
    DEP_INST=0
    which jq || DEP_INST=1
    which wget || DEP_INST=1
    which curl || DEP_INST=1
    which traceroute || DEP_INST=1

    if [[ "$DEP_INST" != '0' ]]; then
        echo -n ' Installing...' >&2
        apt-get -y -qq update && apt-get -y -qq install jq wget curl traceroute
    fi
    echo -n ' Dep: OK.' >&2

    # cstunnel.sh
    if ! wget --quiet --output-document="$TUN_SH_PATH".tmp "$TUN_SH_URL" ; then
        echo "Failed: Error while trying to wget cstunnel.sh!"
        exit 1
    else
        if [[ -f "$TUN_SH_PATH" ]]; then
            mv "$TUN_SH_PATH" "$TUN_SH_PATH".bak
        fi
        mv "$TUN_SH_PATH".tmp "$TUN_SH_PATH"
        chmod +x "$TUN_SH_PATH"
    fi
    echo -n ' Tunnel script: OK.' >&2

    # systemd conf
    if ! wget --quiet --output-document="$SYSD_PATH" "$SYSD_URL" ; then
        echo "Failed: Error while trying to wget cstunnel.service!"
        exit 1
    else
        systemctl daemon-reload
        systemctl enable cstunnel
    fi
    echo -n ' Systemd script: OK.' >&2

    # Getting params
    KEY=$2
    CSPARAMS_URL="https://cloud-shield.ru/tunnel-params.php?key="$KEY""
    res=$(curl -s "$CSPARAMS_URL")
    CS_REMOTE_IP=$(echo $res | jq .cs-remote-ip)
    CS_PROTECT_IP=$(echo $res | jq .cs-protect-ip)
    TUN_TYPE=$(echo $res | jq .tun-type)

    if [[ ! -z "$CS_REMOTE_IP" ]] && [[ ! -z "$CS_PROTECT_IP" ]] && [[ ! -z "$TUN_TYPE" ]]; then
        echo "Failed: Error while trying to get params from CS!"
        exit 1
    fi

    IFDEV=$(ip route get 8.8.8.8 | awk '{printf $5}')
    LOCAL_IP=$(curl -s https://ipinfo.io/ip)

    if [[ ! -z "$IFDEV" ]] && [[ ! -z "$LOCAL_IP" ]]; then
        echo "Failed: Error while trying to get local params!"
        exit 1
    fi

    echo -n ' Getting params: OK.' >&2

    # Setting params
    sed -i 's/replace-me_ifdev-name/$IFDEV/g' "$TUN_SH_PATH"
    sed -i 's/replace-me_local-ip/$LOCAL_IP/g' "$TUN_SH_PATH"
    sed -i 's/replace-me_cs-remote-ip/$CS_REMOTE_IP/g' "$TUN_SH_PATH"
    sed -i 's/replace-me_cs-protect-ip/$CS_PROTECT_IP/g' "$TUN_SH_PATH"
    sed -i 's/replace-me_tun-type/$TUN_TYPE/g' "$TUN_SH_PATH"

    echo -n ' Setting params: OK.' >&2

    # systemctl start cstunnel
    echo ' done'. >&2

    echo -n 'Starting tunnel...' >&2
    systemctl start cstunnel
    echo ' done'. >&2

    echo 'Usage: systemctl start cstunnel'
    echo 'Usage: systemctl stop cstunnel'
}

function uninstall {
    echo -n Removing... >&2

    systemctl stop cstunnel
    bash "$TUN_SH_PATH" down
    rm "$TUN_SH_PATH"
    rm "$SYSD_PATH"
    #TODO: clear rt_tables
    systemctl daemon-reload

    echo ' done'. >&2
}

function debug {
    echo "=== DATE ==="
    date
    echo "=== SYS ==="
    uname -a
    lsb_release -a
    echo "=== IP ADDR ==="
    ip addr
    echo "=== IP LINK ==="
    ip link
    echo "=== SETUP DEBUG END ==="
}

case "$1" in
    "install")
        install $@
    ;;
    "remove")
        uninstall
    ;;
    "debug")
        debug
    ;;
    *)
        echo "Usage: $0 (install|uninstall|debug) (your_secret_key_here)"
    ;;
esac
