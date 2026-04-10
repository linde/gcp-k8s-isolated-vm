resource "kubernetes_deployment" "proxy" {
  metadata {
    name      = "${var.name_prefix}-${local.suffix}"
    namespace = "default"
    labels = {
      app = "${var.name_prefix}-${local.suffix}"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "${var.name_prefix}-${local.suffix}"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "${var.name_prefix}-${local.suffix}"
        }
      }

      spec {
        host_network = true

        container {
          name  = "proxy"
          image = "debian:bookworm-slim"

          security_context {
            privileged = true
          }

          command = ["/bin/sh", "-c", <<EOF
apt-get update && apt-get install -y iproute2 iptables socat procps strongswan

mkdir -p /etc/ipsec.d/cacerts /etc/ipsec.d/certs /etc/ipsec.d/private

cat << 'EOT' > /etc/ipsec.d/cacerts/ca.crt
${var.ca_cert}
EOT

cat << 'EOT' > /etc/ipsec.d/certs/peer.crt
${var.proxy_tls_cert}
EOT

cat << 'EOT' > /etc/ipsec.d/private/peer.key
${var.proxy_tls_key}
EOT

chmod 600 /etc/ipsec.d/private/peer.key

NODE_IP=$(ip route show default | head -n1 | awk '{print $5}' | xargs -I{} ip -4 -o addr show dev {} | awk '{print $4}' | cut -d/ -f1)

cat << EOT > /etc/ipsec.conf
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn %default
    ikelifetime=60m
    keylife=20m
    rekeymargin=3m
    keyingtries=1
    keyexchange=ikev2

conn tunnel
    left=\$NODE_IP
    leftcert=peer.crt
    right=${google_compute_address.proxied_vm_ip.address}
    rightid=%any
    type=transport
    auto=start
EOT

cat << 'EOT' > /etc/ipsec.secrets
: RSA peer.key
EOT

ipsec restart

ip link del geneve${var.tunnel_id} 2>/dev/null || true

ip link add name geneve${var.tunnel_id} type geneve id ${var.tunnel_id} remote ${google_compute_address.proxied_vm_ip.address}
ip addr add 192.168.${var.tunnel_id}.1/24 dev geneve${var.tunnel_id}
ip link set geneve${var.tunnel_id} up

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 192.168.${var.tunnel_id}.0/24 -o ens4 -j MASQUERADE

%{ for p in var.proxied_ports ~}
socat TCP-LISTEN:${p},reuseaddr,fork TCP:192.168.${var.tunnel_id}.2:${p} &
%{ endfor ~}
wait
EOF
          ]
        }
      }
    }
  }
}

resource "kubernetes_service" "proxy" {
  metadata {
    name      = "${var.name_prefix}-svc"
    namespace = "default"
  }

  spec {
    type = "LoadBalancer"

    dynamic "port" {
      for_each = var.proxied_ports
      content {
        name        = "port-${port.value}"
        port        = port.value
        target_port = port.value
      }
    }

    selector = {
      app = "${var.name_prefix}-${local.suffix}"
    }
  }
}
