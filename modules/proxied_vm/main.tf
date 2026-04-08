locals {
  suffix = var.name_suffix != "" ? var.name_suffix : "default"
}

resource "google_compute_address" "proxied_vm_ip" {
  name         = "proxied-vm-ip-${local.suffix}"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork_id
}

resource "google_compute_instance" "proxied_vm" {
  name         = "proxied-vm-${local.suffix}"
  project      = var.gcp_project
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["k8s-node"]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = 20
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.subnetwork_id
    network_ip = google_compute_address.proxied_vm_ip.address
    access_config {}
  }

  metadata = {
    "ssh-keys" = "admin:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/scripts/proxied_vm_startup.sh.tftpl", {
    worker_node_ip = var.worker_node_ip
    proxied_ports  = var.proxied_ports
  })
}
