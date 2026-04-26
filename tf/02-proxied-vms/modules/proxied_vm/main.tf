locals {
  suffix = var.name_suffix != "" ? var.name_suffix : "default"
  vm_tunnel_ip = "192.168.${var.tunnel_id}.2"
  gw_tunnel_ip = "192.168.${var.tunnel_id}.1"
  tunnel_cidr  = "192.168.${var.tunnel_id}.0/24"
}

resource "google_compute_address" "static_ip" {
  name         = "${var.name_prefix}-ip-${var.name_suffix}"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork_id
  project      = var.gcp_project
}

resource "google_compute_firewall" "allow_proxied_ports" {
  name        = "allow-proxied-${var.name_prefix}-${var.name_suffix}"
  project     = var.gcp_project
  network     = var.network_id
  target_tags = ["${var.name_prefix}-node-${var.name_suffix}"]

  allow {
    protocol = "tcp"
    ports    = [for p in var.proxied_ports : tostring(p)]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_geneve_tunnel" {
  name        = "allow-geneve-${var.name_prefix}-${var.name_suffix}"
  project     = var.gcp_project
  network     = var.network_id
  target_tags = ["${var.name_prefix}-node-${var.name_suffix}"]

  allow {
    protocol = "udp"
    ports    = ["6081"]
  }

  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_instance" "proxied_vm" {
  name         = "${var.name_prefix}-${local.suffix}"
  project      = var.gcp_project
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["k8s-node", "${var.name_prefix}-node-${var.name_suffix}"]

  metadata = {
    # TODO reconcile this with the other "admin" users (or remove)
    ssh-keys = "debian:${var.ssh_public_key}"
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
    proxied_ports  = var.proxied_ports
    tunnel_id      = var.tunnel_id
    vm_tunnel_ip   = local.vm_tunnel_ip
    gw_tunnel_ip   = local.gw_tunnel_ip
    k8s_subnet_cidr = var.k8s_subnet_cidr

    python_daemon  = templatefile("${path.module}/templates/proxied_test.py.tftpl", {
      bind_address  = local.vm_tunnel_ip
      proxied_ports = jsonencode(var.proxied_ports)
    })
  })
}





