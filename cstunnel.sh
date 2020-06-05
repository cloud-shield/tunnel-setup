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

### PARAMS ###

# IFDEV example: eth0 / ens18
IFDEV=replace-me_ifdev-name
# Your server IP
LOCAL_IP=replace-me_local-ip
# Get from CS
CS_REMOTE_IP=replace-me_cs-remote-ip
# Get from CS
CS_PROTECT_IP=replace-me_cs-protect-ip
# TUN_TYPE: GRE / IPIP
TUN_TYPE=replace-me_tun-type

TUN_PREFIX=cstun1

###################################################################################

OFFSET=40

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

    ip address add $CS_PROTECT_IP/32 dev "$TUN_PREFIX"
    ip link set "$TUN_PREFIX" up
    ip rule add from $CS_PROTECT_IP table "$TUN_PREFIX"_route
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
    echo "=== DATE ==="
    date
    echo "=== SYS ==="
    uname -a
    lsb_release -a
    echo "=== IP ADDR ==="
    ip addr
    echo "=== IP LINK ==="
    ip link
    echo "=== IP RULE ==="
    ip rule
    echo "=== IP ROUTE ==="
    ip route
    echo "=== NETSTAT ==="
    netstat -tunap
    echo "=== PING (ENDPOINTS) ==="
    ping $CS_PROTECT_IP -n -c 4 -w 1
    echo "=== TRACEROUTE (ENDPOINTS) ==="
    traceroute $CS_PROTECT_IP -n -w 2
    echo "=== PING (GATEWAYS) ==="
    ping $CS_REMOTE_IP -n -c 4 -w 1
    echo "=== ROUTES (GATEWAYS) ==="
    ip route get $CS_REMOTE_IP
    echo "=== ROUTES (ENDPOINTS) ==="
    ip route get $CS_PROTECT_IP
    echo "=== IPTABLES-SAVE ==="
    iptables-save
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
