resource "random_id" "rand" {
  byte_length = 4
}

locals {
  zone        = "${data.terraform_remote_state.base.outputs.region}-a"
  rand_suffix = random_id.rand.hex
}

module "proxied_vm" {
  source         = "./modules/proxied_vm"
  for_each       = var.proxied_vms

  gcp_project    = data.terraform_remote_state.base.outputs.gcp_project
  region         = data.terraform_remote_state.base.outputs.region
  zone           = local.zone
  network_id     = data.terraform_remote_state.base.outputs.network_id
  subnetwork_id  = data.terraform_remote_state.base.outputs.subnetwork_id
  os_image       = var.os_image
  worker_node_ip = data.terraform_remote_state.base.outputs.worker_node_ip
  proxied_ports  = each.value
  ssh_public_key = tls_private_key.vm_ssh_key.public_key_openssh
  name_prefix    = each.key
  name_suffix    = local.rand_suffix
  tunnel_id      = 100 + index(sort(keys(var.proxied_vms)), each.key)

  # Inject mTLS parameters for socat transport encryption on the VM side
  ca_cert       = tls_self_signed_cert.ca.cert_pem
  vm_tls_cert   = tls_locally_signed_cert.vm.cert_pem
  vm_tls_key    = tls_private_key.vm.private_key_pem
}

resource "local_file" "proxied_pod_manifest" {
  for_each = var.proxied_vms
  filename = "${path.module}/.tmp/manifests/proxy-svc-${each.key}.yaml"
  content = templatefile("${path.module}/scripts/proxy-svc.yaml.tftpl", {
    name_prefix    = each.key
    name_suffix    = local.rand_suffix
    proxied_vm_ip  = module.proxied_vm[each.key].proxied_vm_ip
    proxied_ports  = each.value
    tunnel_id      = 100 + index(sort(keys(var.proxied_vms)), each.key)
    ipsec_psk      = module.proxied_vm[each.key].ipsec_psk

    # Inject mTLS parameters for inline heredoc rendering in the proxy pod startup script
    ca_cert        = tls_self_signed_cert.ca.cert_pem
    proxy_tls_cert = tls_locally_signed_cert.proxy.cert_pem
    proxy_tls_key  = tls_private_key.proxy.private_key_pem
  })
}
