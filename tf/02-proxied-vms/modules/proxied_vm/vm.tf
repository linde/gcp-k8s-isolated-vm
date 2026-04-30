
resource "google_compute_instance" "proxied_vm" {
  name         = "${var.name_prefix}-${local.suffix}"
  project      = var.gcp_project
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["k8s-node", "${var.name_prefix}-node-${var.name_suffix}"]

  metadata = {
    ssh-keys = "${var.unix_user}:${var.ssh_public_key}"
  }

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = 20
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.subnetwork_id
    network_ip = google_compute_address.static_ip.address
    access_config {}
  }

  metadata_startup_script = templatefile("${path.module}/templates/proxied_vm_startup.sh.tftpl", {
    pod_tunnel_endpoint_ip = kubernetes_service.geneve_tunnel.status[0].load_balancer[0].ingress[0].ip
    proxied_ports          = var.proxied_ports
    worker_node_ip         = var.worker_node_ip
    tunnel_id              = var.tunnel_id
    vm_tunnel_ip           = local.vm_tunnel_ip
    gw_tunnel_ip           = local.gw_tunnel_ip
    k8s_subnet_cidr        = var.k8s_subnet_cidr


    python_daemon = templatefile("${path.module}/templates/proxied_test.py.tftpl", {
      bind_address  = local.vm_tunnel_ip
      proxied_ports = jsonencode(var.proxied_ports)
    })
  })
}


