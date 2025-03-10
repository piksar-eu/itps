#!/bin/bash
### BEGIN INIT INFO
# Provides:          skrypt
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: wg-networking
# Description:       Enable service provided by daemon.
### END INIT INFO

ip link add wg0 type wireguard
ip addr add 10.8.0.2/24 dev wg0
wg set wg0 private-key /etc/wireguard/private.key
ip link set wg0 up
wg set wg0 peer LzjE0cdkFT+6ilng2+VX/waOpLjboRT/4ChwY8qX9jU= allowed-ips 0.0.0.0/0 endpoint 57.128.194.184:51820 persistent-keepalive 60