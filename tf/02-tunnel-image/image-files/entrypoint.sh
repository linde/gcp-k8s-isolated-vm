#!/bin/sh
set -e

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Clean up existing link if present
ip link del geneve0 2>/dev/null || true

# Create the Geneve interface using env variables
ip link add name geneve0 type geneve id "$TUNNEL_ID" remote "$PROXIED_VM_IP"
ip addr add "192.168.$TUNNEL_ID.1/24" dev geneve0
ip link set geneve0 up

# Setup iptables - Space separated words list
ports_list=$(echo "$PROXIED_PORTS" | sed 's/,/ /g')

# Except app proxy ports
for p in $ports_list; do
  iptables -t nat -A PREROUTING -p tcp --dport "$p" -j ACCEPT
done

# Except health checks port
iptables -t nat -A PREROUTING -p tcp --dport "$HEALTH_CHECK_PORT" -j ACCEPT

# Broad DNAT for all other target traffic
iptables -t nat -A PREROUTING -p tcp -j DNAT --to-destination "$VM_TUNNEL_IP"

iptables -t nat -A POSTROUTING -p tcp -d "$VM_TUNNEL_IP" -j MASQUERADE

# Build Gunicorn bind arguments
BND_ARGS=""
for p in $ports_list; do
  BND_ARGS="$BND_ARGS -b 0.0.0.0:$p"
done
BND_ARGS="$BND_ARGS -b 0.0.0.0:$HEALTH_CHECK_PORT"

# Execute gunicorn
exec gunicorn $BND_ARGS proxied_test:app

