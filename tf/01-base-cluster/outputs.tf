output "network_id" {
  value       = google_compute_network.k8s.id
  description = "ID of the VPC network"
}

output "subnetwork_id" {
  value       = google_compute_subnetwork.k8s_subnet.id
  description = "ID of the regional subnetwork"
}

output "worker_node_ip" {
  value       = google_compute_instance.worker_node[0].network_interface[0].network_ip
  description = "Internal IP of the Kubernetes worker node"
}

output "kubeconfig_path" {
  value       = "${path.module}/.tmp/kubeconfig.yaml"
  description = "Path to the generated kubeconfig file"
}

output "gcp_project" {
  value       = var.gcp_project
  description = "The GCP project ID hosting the infrastructure"
}

output "region" {
  value       = var.region
  description = "The GCP region hosting the infrastructure"
}
