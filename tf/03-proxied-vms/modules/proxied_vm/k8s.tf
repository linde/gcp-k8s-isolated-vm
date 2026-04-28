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
          image = "nicolaka/netshoot:latest"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOF
            echo 1 > /proc/sys/net/ipv4/ip_forward
            ip link del geneve0 2>/dev/null || true
            ip link add name geneve0 type geneve id "$TUNNEL_ID" remote "$PROXIED_VM_IP"
            ip addr add "192.168.$TUNNEL_ID.1/24" dev geneve0
            ip link set geneve0 up                       

            iptables -t nat -A PREROUTING -i eth0 -p tcp -j DNAT --to-destination "$VM_TUNNEL_IP"
            iptables -t nat -A POSTROUTING -p tcp -d "$VM_TUNNEL_IP" -j MASQUERADE
            iptables -t nat -A POSTROUTING -s 192.168.$TUNNEL_ID.0/24 -o eth0 -j MASQUERADE
            
            sleep infinity
            EOF
          ]

          security_context {
            privileged = true
          }

          env {
            name  = "PROXIED_VM_IP"
            value = google_compute_address.static_ip.address
          }

          env {
            name  = "TUNNEL_ID"
            value = var.tunnel_id
          }
          env {
            name  = "VM_TUNNEL_IP"
            value = local.vm_tunnel_ip
          }        
          env {
            name  = "WORKER_NODE_IP"
            value = var.worker_node_ip
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

          readiness_probe {
            exec {
              # TODO make geneve0 a local variable
              command = ["ip", "link", "show", "geneve0"]
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
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
      "networking.gke.io/internal-load-balancer-subnet" = var.subnetwork_name
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


