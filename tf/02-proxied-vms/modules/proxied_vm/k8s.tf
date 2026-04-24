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
          # Using kube-proxy image NOT for its functionality, but because it contains iptables tools.
          image = "registry.k8s.io/kube-proxy:v1.32.13"

          security_context {
            privileged = true
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

          command = ["/bin/sh", "-c", <<EOF
echo 1 > /proc/sys/net/ipv4/ip_forward
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


