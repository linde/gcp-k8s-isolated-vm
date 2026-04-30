locals {
  suffix       = var.name_suffix != "" ? var.name_suffix : "default"
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
  name    = "allow-geneve-${var.name_prefix}-${var.name_suffix}"
  project = var.gcp_project
  network = var.network_id

  allow {
    protocol = "udp"
    ports    = ["6081"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}



