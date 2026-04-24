
module "proxied_vm" {
  source         = "./modules/proxied_vm"
  for_each       = data.terraform_remote_state.base.outputs.proxied_vms 

  gcp_project    = data.terraform_remote_state.base.outputs.gcp_project
  region         = data.terraform_remote_state.base.outputs.region
  zone           = data.terraform_remote_state.base.outputs.zone
  network_id     = data.terraform_remote_state.base.outputs.network_id
  subnetwork_id  = data.terraform_remote_state.base.outputs.subnetwork_id
  os_image       = var.os_image
  worker_node_ip = data.terraform_remote_state.base.outputs.worker_node_ip
  proxied_ports  = each.value

  name_prefix    = each.key 
  name_suffix    = data.terraform_remote_state.base.outputs.rand_suffix
  tunnel_id      = 100 + index(sort(keys(data.terraform_remote_state.base.outputs.proxied_vms)), each.key)
  static_ip      = data.terraform_remote_state.base.outputs.proxied_vm_static_ips[each.key]
  ssh_public_key = data.terraform_remote_state.base.outputs.vm_ssh_public_key
}

module "proxied_vm_with_proxy" {
  source         = "./modules/proxied_vm"

  gcp_project    = data.terraform_remote_state.base.outputs.gcp_project
  region         = data.terraform_remote_state.base.outputs.region
  zone           = data.terraform_remote_state.base.outputs.zone
  network_id     = data.terraform_remote_state.base.outputs.network_id
  subnetwork_id  = data.terraform_remote_state.base.outputs.subnetwork_id
  os_image       = var.os_image
  worker_node_ip = data.terraform_remote_state.base.outputs.worker_node_ip
  proxied_ports  = [80]

  name_prefix    = "proxied-with-proxy"
  name_suffix    = data.terraform_remote_state.base.outputs.rand_suffix
  tunnel_id      = 200
  static_ip      = data.terraform_remote_state.base.outputs.proxied_vm_static_ips["httpbin1"] 
  ssh_public_key = data.terraform_remote_state.base.outputs.vm_ssh_public_key

  egress_proxy_url = "http://egress-gateway.agentgateway-system.svc.cluster.local:80"
}




