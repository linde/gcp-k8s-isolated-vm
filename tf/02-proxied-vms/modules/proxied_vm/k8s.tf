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
            templatefile("${path.module}/templates/proxy_startup.sh.tftpl", {
              tunnel_id      = var.tunnel_id
              proxied_vm_ip  = google_compute_address.static_ip.address
              vm_tunnel_ip   = local.vm_tunnel_ip
            })
          ]

          security_context {
            privileged = true
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


