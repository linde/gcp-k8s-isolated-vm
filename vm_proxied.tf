module "proxied_vm" {
  source         = "./modules/proxied_vm"
  gcp_project    = var.gcp_project
  region         = var.region
  zone           = local.zone
  network_id     = google_compute_network.k8s.id
  subnetwork_id  = google_compute_subnetwork.k8s_subnet.id
  os_image       = var.os_image
  worker_node_ip = google_compute_instance.worker_node[0].network_interface[0].network_ip
  proxied_ports  = var.proxied_ports
  ssh_public_key = tls_private_key.vm_ssh_key.public_key_openssh
  name_suffix    = local.rand_suffix
}

resource "local_file" "proxied_pod_manifest" {
  filename = "${path.module}/.tmp/proxy-svc.yaml"
  content = templatefile("${path.module}/scripts/proxy-svc.yaml.tftpl", {
    proxied_vm_ip = module.proxied_vm.proxied_vm_ip
    proxied_ports = var.proxied_ports
  })
}
