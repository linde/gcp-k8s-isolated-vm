resource "google_compute_address" "shim_vm_ip" {
  name         = "shim-vm-ip-${local.rand_suffix}"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.k8s_subnet.id
}

resource "google_compute_instance" "shim_vm" {
  name         = "shim-vm-${local.rand_suffix}"
  project      = var.gcp_project
  machine_type = "e2-micro"
  zone         = local.zone
  tags         = ["shim-vm", "k8s-node"] # Using k8s-node allows internal network access easily

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = 20
    }
  }

  network_interface {
    network    = google_compute_network.k8s.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    network_ip = google_compute_address.shim_vm_ip.address
    access_config {} // Ephemeral public IP for provisioning
  }

  metadata = {
    "ssh-keys" = "admin:${tls_private_key.vm_ssh_key.public_key_openssh}"
  }

  metadata_startup_script = templatefile("${path.module}/scripts/shim_vm_startup.sh.tftpl", {
    cp_node_ip = google_compute_instance.cp_node.network_interface[0].network_ip
  })

  depends_on = [time_sleep.wait_for_services, google_compute_instance.cp_node]
}

resource "local_file" "shim_pod_manifest" {
  filename = "${path.module}/.tmp/shim-pod.yaml"
  content = templatefile("${path.module}/scripts/shim-pod.yaml.tftpl", {
    shim_vm_ip        = google_compute_address.shim_vm_ip.address
    inbound_node_port = var.inbound_node_port
  })
}
