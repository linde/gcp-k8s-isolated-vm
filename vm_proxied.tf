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
  tags         = ["proxied-vm-via-${google_compute_instance.worker_node[0].name}", "k8s-node"] # Using k8s-node allows internal network access easily

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

  metadata_startup_script = templatefile("${path.module}/scripts/proxied_vm_startup.sh.tftpl", {})

  depends_on = [time_sleep.wait_for_services]
}

resource "google_compute_route" "vm_to_proxied_egress" {
  name        = "egress-via-proxied-node-${local.rand_suffix}"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.k8s.id
  priority    = 100 # Wins over the default 1000

  # Target only the proxied VM
  tags = ["proxied-vm-via-${google_compute_instance.worker_node[0].name}"]

  # Send traffic to the K8s Worker Node
  next_hop_instance      = google_compute_instance.worker_node[0].self_link
  next_hop_instance_zone = local.zone
}

resource "local_file" "proxied_pod_manifest" {
  filename = "${path.module}/.tmp/proxy-svc.yaml"
  content = templatefile("${path.module}/scripts/proxy-svc.yaml.tftpl", {
    proxied_vm_ip     = google_compute_address.proxied_vm_ip.address
  })
}
