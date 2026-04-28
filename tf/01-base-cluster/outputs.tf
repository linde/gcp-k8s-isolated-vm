output "control_plane_public_ip" {
  description = "Public IP of the control plane node"
  value       = google_compute_instance.cp_node.network_interface[0].access_config[0].nat_ip
}

output "gcp_project" {
  description = "The GCP project ID hosting the infrastructure"
  value       = var.gcp_project
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = abspath(local.kubeconfig_path)
}

output "network_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.k8s.id
}



output "rand_suffix" {
  description = "Random suffix generated for resource naming"
  value       = random_id.rand.hex
}

output "region" {
  description = "The GCP region hosting the infrastructure"
  value       = var.region
}

output "ssh_key_path" {
  description = "Path to the generated SSH private key"
  value       = abspath(local_file.private_key.filename)
}

output "subnetwork_id" {
  description = "ID of the regional subnetwork"
  value       = google_compute_subnetwork.k8s_subnet.id
}

output "subnetwork_name" {
  description = "Name of the regional subnetwork"
  value       = google_compute_subnetwork.k8s_subnet.name
}

output "vm_ssh_public_key" {
  description = "The public SSH key for the control plane and runner VMs"
  value       = tls_private_key.vm_ssh_key.public_key_openssh
}

output "worker_node_ip" {
  description = "Internal IP of the Kubernetes worker node"
  value       = google_compute_instance.worker_node[0].network_interface[0].network_ip
}

output "zone" {
  description = "The GCP zone where the Kubernetes worker node resides"
  value       = google_compute_instance.worker_node[0].zone
}

output "gke_node_service_account_email" {
  description = "The service account email for GKE nodes"
  value       = google_service_account.k8s_node.email
}

output "k8s_subnet_cidr" {
  description = "Subnet CIDR mapping cluster paths"
  value       = var.k8s_subnet_cidr
}

output "k8s_pod_cidr" {
  description = "Pods network range CIDR"
  value       = var.k8s_pod_cidr
}