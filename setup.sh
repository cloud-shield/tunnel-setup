#!/bin/bash

###################################################################################
##
## Cloud-Shield Linux/BSD install script for Tunnel Configurator
## Version: 1.2
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
        echo "Usage: $0 install your_secret_key_here"
        exit 1
    fi

    # dependencies
    echo -n 'Checking dependencies...' >&2
    DEP_INST=0
    PM=""
    which jq > /dev/null || DEP_INST=1
    which wget > /dev/null || DEP_INST=1
    which curl > /dev/null || DEP_INST=1
    which traceroute > /dev/null || DEP_INST=1
    which apt-get > /dev/null && PM="deb"
    which yum > /dev/null && PM="yum"

    if [[ "$DEP_INST" != '0' ]]; then
        echo -n ' Installing...' >&2

        if [[ "$PM" == 'deb' ]]; then
            apt-get -y -qq update && apt-get -y -qq install jq wget curl traceroute
        elif [[ "$PM" == 'yum' ]]; then
            yum -y -q update && yum -y -q install jq wget curl traceroute
        else
            echo "Failed: You have to manually install: jq wget curl traceroute"
            exit 1
        fi

    fi
    echo -n ' OK.' >&2

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
    CSPARAMS_URL="https://cloud-shield.ru/api/tunnel-params.php?key="$KEY""
    res=$(curl -s -k -H "cs-tunnel-scr: 1" "$CSPARAMS_URL")
    CS_REMOTE_IP=$(echo $res | jq -rc .cs_remote_ip)
    LOCAL_IP=$(echo $res | jq -rc .client_ip)
    TUN_TYPE=$(echo $res | jq -rc .tun_type)
    CS_PROTECTED_IPS=$(echo $res | jq -rc .cs_protected_ips | sed 's/,/ /g' | sed 's/\[/(/g' | sed 's/\]/)/g')

    if [[ -z "$CS_REMOTE_IP" ]] || [[ -z "$CS_PROTECTED_IPS" ]] || [[ -z "$TUN_TYPE" ]]; then
        echo "Failed: Error while trying to get params from CS!"
        exit 1
    fi

    IFDEV=$(ip route get 8.8.8.8 | awk '{printf $5}')

    if [[ -z "$LOCAL_IP" ]]; then
        LOCAL_IP=$(curl -s https://ipinfo.io/ip)
    fi

    if [[ -z "$IFDEV" ]] || [[ -z "$LOCAL_IP" ]]; then
        echo "Failed: Error while trying to get local params!"
        exit 1
    fi

    echo -n ' Getting params: OK.' >&2

    # Setting params
    sed -i "s/replace-me_ifdev-name/$IFDEV/g" "$TUN_SH_PATH"
    sed -i "s/replace-me_local-ip/$LOCAL_IP/g" "$TUN_SH_PATH"
    sed -i "s/replace-me_cs-remote-ip/$CS_REMOTE_IP/g" "$TUN_SH_PATH"
    sed -i "s/replace-me_cs-protected-ips/$CS_PROTECTED_IPS/g" "$TUN_SH_PATH"
    sed -i "s/replace-me_tun-type/$TUN_TYPE/g" "$TUN_SH_PATH"

    echo -n ' Setting params: OK.' >&2

    # systemctl start cstunnel
    echo ' done'. >&2

    echo -n 'Starting tunnel...' >&2
    systemctl stop cstunnel
    systemctl start cstunnel
    echo ' done'. >&2

    echo 'Usage: systemctl start cstunnel'
    echo 'Usage: systemctl stop cstunnel'
    echo 'Usage: cstunnel debug'
}

function uninstall {
    echo -n Removing... >&2

    systemctl stop cstunnel
    bash "$TUN_SH_PATH" down >/dev/null
    rm "$TUN_SH_PATH"
    rm "$SYSD_PATH"
    #TODO: clear rt_tables
    systemctl daemon-reload

    echo ' done'. >&2
}

function debug {
    #TODO: show script version
    #TODO: print head -x of /usr/local/bin/cstunnel for vars
    echo "=== DATE ==="
    date
    echo "=== SYS ==="
    uname -a
    cat /etc/os-release
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
    "uninstall")
        uninstall
    ;;
    "debug")
        debug
    ;;
    *)
        echo "Usage: $0 (install|uninstall|debug) (your_secret_key_here)"
    ;;
esac
