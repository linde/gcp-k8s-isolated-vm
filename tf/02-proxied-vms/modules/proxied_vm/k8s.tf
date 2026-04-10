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
apt-get update && apt-get install -y iproute2 iptables socat procps

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
