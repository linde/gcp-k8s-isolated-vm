


module "proxied_vm" {
  source   = "./modules/proxied_vm"
  for_each = var.proxied_vms


  gcp_project     = data.terraform_remote_state.base.outputs.gcp_project
  region          = data.terraform_remote_state.base.outputs.region
  zone            = data.terraform_remote_state.base.outputs.zone
  network_id      = data.terraform_remote_state.base.outputs.network_id
  subnetwork_id   = data.terraform_remote_state.base.outputs.subnetwork_id
  subnetwork_name = data.terraform_remote_state.base.outputs.subnetwork_name
  os_image        = var.os_image
  worker_node_ip  = data.terraform_remote_state.base.outputs.worker_node_ip
  proxied_ports   = each.value

  name_prefix          = each.key
  name_suffix          = data.terraform_remote_state.base.outputs.rand_suffix
  tunnel_id            = 100 + index(sort(keys(var.proxied_vms)), each.key)
  ssh_private_key_path = data.terraform_remote_state.base.outputs.ssh_key_path
  ssh_public_key       = data.terraform_remote_state.base.outputs.vm_ssh_public_key
  k8s_subnet_cidr      = data.terraform_remote_state.base.outputs.k8s_subnet_cidr
} 
 