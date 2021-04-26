#!/bin/bash

###################################################################################
##
## Cloud-Shield Linux/BSD install script for Tunnel Configurator
## Version: 1.3
## https://github.com/cloud-shield/tunnel-setup
##
## https://cloud-shield.ru
## support@cloud-shield.ru
##
###################################################################################

### PARAMS ###

# IFDEV example: eth0 or ens18
IFDEV=replace-me_ifdev-name
# Your server IP
LOCAL_IP=replace-me_local-ip
# Get from CS
CS_REMOTE_IP=replace-me_cs-remote-ip
# Get from CS
CS_PROTECTED_IPS=replace-me_cs-protected-ips
CS_PROTECT_IP=${CS_PROTECTED_IPS[0]}

# TUN_TYPE: gre/ipip
TUN_TYPE=replace-me_tun-type

TUN_PREFIX=cstun1
# TUN_MTU: 1476 / 1400
TUN_MTU=1476

###################################################################################

OFFSET=40
CS_PROTECT_GW=$(echo $CS_PROTECT_IP | sed -r "s/([0-9]+)$/1/")

function tun_up {
    if ip link sh "$TUN_PREFIX" &>/dev/null; then
        echo 'Tunnel is set up already, nothing to do.' >&2
        exit 1
    fi

    if [ -z "$IFDEV" ]; then
        echo "$IFDEV unset"
        exit 1
    fi

    if [ -z "$LOCAL_IP" ]; then
        echo "$LOCAL_IP unset"
        exit 1
    fi

    if ! modprobe $TUN_TYPE; then
        echo "Failed to load $TUN_TYPE module"
        exit 1
    fi

    if ! grep -q "$TUN_PREFIX"_route /etc/iproute2/rt_tables; then
        if egrep -q '^[[:space:]]*'$OFFSET'[[:space:]]' /etc/iproute2/rt_tables; then
            echo Cannot append appropriate lines to /etc/iproute2/rt_tables. >&2
            echo You need to set up "$TUN_PREFIX"_route table yourself. >&2
            exit
        else
            echo ' '$OFFSET' '$TUN_PREFIX'_route' >> /etc/iproute2/rt_tables
        fi
    fi

    echo -n Setting up tunnel... >&2

    ip tunnel add "$TUN_PREFIX" mode $TUN_TYPE local $LOCAL_IP remote $CS_REMOTE_IP ttl 64 dev $IFDEV
    #ip address add $CS_PROTECT_IP/32 dev "$TUN_PREFIX"
    ip link set "$TUN_PREFIX" mtu "$TUN_MTU" up

    for PIP in "${CS_PROTECTED_IPS[@]}"; do
        ip address add "$PIP"/32 dev "$TUN_PREFIX"
        ip rule add from "$PIP" table "$TUN_PREFIX"_route
    done

    #ip rule add from $CS_PROTECT_IP table "$TUN_PREFIX"_route
    ip route add default dev "$TUN_PREFIX" table "$TUN_PREFIX"_route

    echo ' done'. >&2
}

function tun_down {
    echo -n Setting down tunnel... >&2
    ip link delete "$TUN_PREFIX"
    echo ' done'. >&2
}

function debug {
    #TODO: add checks if netstat and traceroute are exist
    #TODO: replace netstat to ss
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
    echo "=== IP RULE ==="
    ip rule
    echo "=== IP ROUTE ==="
    echo "# ip route"
    ip route
    echo "# ip route show table $OFFSET"
    ip route show table $OFFSET
    echo "=== NETSTAT ==="
    echo "# netstat -tunap"
    netstat -tunap
    echo "=== PING (ENDPOINTS) ==="
    echo "# ping $CS_PROTECT_IP -n -c 4 -w 1"
    ping $CS_PROTECT_IP -n -c 4 -w 1
    echo "=== TRACEROUTE (ENDPOINTS) ==="
    echo "# traceroute $CS_PROTECT_IP -n -w 2"
    traceroute $CS_PROTECT_IP -n -w 2
    echo "=== PING (GATEWAYS) ==="
    echo "# ping $CS_REMOTE_IP -n -c 4 -w 1"
    ping $CS_REMOTE_IP -n -c 4 -w 1
    echo "# ping -I $TUN_PREFIX $CS_PROTECT_GW -n -c 4 -w 1"
    ping -I $TUN_PREFIX $CS_PROTECT_GW -n -c 4 -w 1
    echo "=== ROUTES (GATEWAYS) ==="
    echo "# ip route get $CS_REMOTE_IP"
    ip route get $CS_REMOTE_IP
    echo "=== ROUTES (ENDPOINTS) ==="
    echo "# ip route get $CS_PROTECT_IP"
    ip route get $CS_PROTECT_IP
    echo "=== IPTABLES-SAVE ==="
    iptables-save
    echo "=== CURL (TUN) ==="
    echo "# curl --interface $TUN_PREFIX --connect-timeout 5 https://ipinfo.io"
    curl --interface $TUN_PREFIX --connect-timeout 5 https://ipinfo.io
    echo "=== TUNNEL DEBUG END ==="
}

case "$1" in
    "up")
        tun_up
    ;;
    "down")
        tun_down
    ;;
    "debug")
        debug
    ;;
    *)
        echo "Usage: $0 (up|down|debug)"
        exit 1
    ;;
esac
