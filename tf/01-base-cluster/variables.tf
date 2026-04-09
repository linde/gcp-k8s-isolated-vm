
## input variables

variable "gcp_project" {
  type        = string
  description = "The GCP project ID to deploy into."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The GCP region for deployment."
}

variable "machine_type" {
  type        = string
  default     = "e2-standard-4"
  description = "The machine type for both control plane and worker nodes."
}

variable "k8s_version" {
  type        = string
  default     = "1.32"
  description = "The version of Kubernetes to install (e.g., 1.32, 1.34)."
}

variable "os_image" {
  type        = string
  default     = "debian-cloud/debian-13"
  description = "The boot image for the instances."
}

variable "k8s_subnet_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "The CIDR range for the Kubernetes subnet."
}

variable "proxied_vms" {
  type        = map(list(number))
  default     = {
    httpbin1 = [80, 8080]
    httpbin2 = [8888]
  }
  description = "Mapping of VM name prefixes to lists of exposed ports."
}

resource "random_id" "rand" {
  byte_length = 4
}

locals {
  zone        = "${var.region}-a"
  rand_suffix = random_id.rand.hex
}

variable "worker_node_count" {
  type        = number
  default     = 1
  description = "The number of worker nodes to provision."

  validation {
    condition     = var.worker_node_count >= 1 && var.worker_node_count <= 253
    error_message = "worker_node_count must be between 1 and 253 because kubeadm natively allocates a /24 (254 addresses) per node, and we are using a 192.168.0.0/16 cluster CIDR."
  }
}

variable "inbound_node_port" {
  type        = number
  default     = 30080
  description = "The NodePort used for inbound traffic to the proxied VM via the Envoy proxy."

  validation {
    condition     = var.inbound_node_port >= 30000 && var.inbound_node_port <= 32767
    error_message = "inbound_node_port must be between 30000 and 32767, which is the default NodePort range in Kubernetes."
  }
}


###  output variables

output "control_plane_public_ip" {
  value = google_compute_instance.cp_node.network_interface[0].access_config[0].nat_ip
}

output "ssh_key_path" {
  value       = abspath(local_file.private_key.filename)
  description = "Path to the generated SSH private key"
}
