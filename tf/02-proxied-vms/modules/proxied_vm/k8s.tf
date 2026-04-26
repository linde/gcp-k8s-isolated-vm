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
        host_network = false

        container {
          name  = "proxy"
          # Using debian thin image and installing required tools on boot.
          image = "debian:bookworm-slim"

          security_context {
            privileged = true
          }

          env {
            name  = "PROXIED_VM_IP"
            value = google_compute_address.static_ip.address
          }

          dynamic "env" {
            for_each = var.egress_proxy_url != "" ? ["HTTP_PROXY", "HTTPS_PROXY"] : []
            content {
              name  = env.value
              value = var.egress_proxy_url
            }
          }

          dynamic "port" {
            for_each = var.proxied_ports
            content {
              container_port = port.value
            }
          }

          port {
            container_port = 6081
            protocol       = "UDP"
          }

          command = ["/bin/sh", "-c", <<EOF
apt-get update && apt-get install -y iproute2 iptables curl
echo 1 > /proc/sys/net/ipv4/ip_forward
ip link del geneve0 2>/dev/null || true
ip link add name geneve0 type geneve id ${var.tunnel_id} remote $PROXIED_VM_IP
ip addr add 192.168.${var.tunnel_id}.1/24 dev geneve0
ip link set geneve0 up
iptables -t nat -A PREROUTING -p tcp -j DNAT --to-destination ${local.vm_tunnel_ip}
iptables -t nat -A POSTROUTING -p tcp -d ${local.vm_tunnel_ip} -j MASQUERADE
while true; do sleep 3600; done
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

resource "kubernetes_service" "geneve_tunnel" {
  metadata {
    name      = "${var.name_prefix}-tunnel-svc"
    namespace = "default"
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "networking.gke.io/internal-load-balancer-subnet" = var.subnetwork_id
    }
  }

  spec {
    type = "LoadBalancer"

    port {
      name        = "geneve"
      port        = 6081
      target_port = 6081
      protocol    = "UDP"
    }

    selector = {
      app = "${var.name_prefix}-${local.suffix}"
    }
  }
}


