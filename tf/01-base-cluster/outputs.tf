output "control_plane_public_ip" {
  value = google_compute_instance.cp_node.network_interface[0].access_config[0].nat_ip
}

output "gcp_project" {
  value       = var.gcp_project
  description = "The GCP project ID hosting the infrastructure"
}

output "kubeconfig_path" {
  value       = abspath(local.kubeconfig_path)
  description = "Path to the generated kubeconfig file"
}

output "network_id" {
  value       = google_compute_network.k8s.id
  description = "ID of the VPC network"
}

output "proxied_vm_static_ips" {
  value       = { for k, v in google_compute_address.proxied_vm_static_ip : k => v.address }
  description = "Map of allocated static internal IPs for proxied VMs."
}

output "region" {
  value       = var.region
  description = "The GCP region hosting the infrastructure"
}

output "ssh_key_path" {
  value       = abspath(local_file.private_key.filename)
  description = "Path to the generated SSH private key"
}

output "subnetwork_id" {
  value       = google_compute_subnetwork.k8s_subnet.id
  description = "ID of the regional subnetwork"
}

output "vm_ssh_public_key" {
  value       = tls_private_key.vm_ssh_key.public_key_openssh
  description = "The public SSH key for the control plane and runner VMs"
}

output "worker_node_ip" {
  value       = google_compute_instance.worker_node[0].network_interface[0].network_ip
  description = "Internal IP of the Kubernetes worker node"
}

output "zone" {
  value       = google_compute_instance.worker_node[0].zone
  description = "The GCP zone where the Kubernetes worker node resides"
}