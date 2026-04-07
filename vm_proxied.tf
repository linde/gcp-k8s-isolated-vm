resource "google_compute_address" "proxied_vm_ip" {
  name         = "proxied-vm-ip-${local.rand_suffix}"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.k8s_subnet.id
}

resource "google_compute_instance" "proxied_vm" {
  name         = "proxied-vm-${local.rand_suffix}"
  project      = var.gcp_project
  machine_type = "e2-micro"
  zone         = local.zone
  tags         = ["k8s-node"] # Standard tags for subnet communication

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = 20
    }
  }

  network_interface {
    network    = google_compute_network.k8s.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = google_compute_address.proxied_vm_ip.address
    access_config {} // Ephemeral public IP for provisioning
  }

  metadata = {
    "ssh-keys" = "admin:${tls_private_key.vm_ssh_key.public_key_openssh}"
  }

  metadata_startup_script = templatefile("${path.module}/scripts/proxied_vm_startup.sh.tftpl", {
    worker_node_ip = google_compute_instance.worker_node[0].network_interface[0].network_ip
  })

  depends_on = [time_sleep.wait_for_services]
}

resource "local_file" "proxied_pod_manifest" {
  filename = "${path.module}/.tmp/proxy-svc.yaml"
  content = templatefile("${path.module}/scripts/proxy-svc.yaml.tftpl", {
    proxied_vm_ip     = google_compute_address.proxied_vm_ip.address
  })
}
