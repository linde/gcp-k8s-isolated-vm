module "proxied_vm" {
  source         = "./modules/proxied_vm"
  for_each       = var.proxied_vms

  gcp_project    = var.gcp_project
  region         = var.region
  zone           = local.zone
  network_id     = google_compute_network.k8s.id
  subnetwork_id  = google_compute_subnetwork.k8s_subnet.id
  os_image       = var.os_image
  worker_node_ip = google_compute_instance.worker_node[0].network_interface[0].network_ip
  proxied_ports  = each.value
  ssh_public_key = tls_private_key.vm_ssh_key.public_key_openssh
  name_prefix    = each.key
  name_suffix    = local.rand_suffix
  tunnel_id      = 100 + index(sort(keys(var.proxied_vms)), each.key)
}

resource "local_file" "proxied_pod_manifest" {
  for_each = var.proxied_vms
  filename = "${path.module}/.tmp/manifests/proxy-svc-${each.key}.yaml"
  content = templatefile("${path.module}/scripts/proxy-svc.yaml.tftpl", {
    name_prefix   = each.key
    name_suffix   = local.rand_suffix
    proxied_vm_ip = module.proxied_vm[each.key].proxied_vm_ip
    proxied_ports = each.value
    tunnel_id     = 100 + index(sort(keys(var.proxied_vms)), each.key)
  })
}
