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
          # Using custom tunnel image.
          image = var.tunnel_image

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
            name  = "PROXIED_PORTS"
            value = join(",", var.proxied_ports)
          }
          env {
            name  = "HEALTH_CHECK_PORT"
            value = var.health_check_port
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

          readiness_probe {
            tcp_socket {
              port = var.health_check_port
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


