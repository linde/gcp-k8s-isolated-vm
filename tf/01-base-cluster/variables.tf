## primary inputs

variable "gcp_project" {
  description = "(REQUIRED) The GCP project ID to deploy into."
  type        = string
}

variable "proxied_vms" {
  description = "Mapping of VM name prefixes to lists of exposed ports"
  type = map(list(number))
  default = {
    httpbin1 = [8080]
    httpbin2 = [8080, 8888]
  }
  validation {
    condition = alltrue([
      for ports in var.proxied_vms : length(ports) == length(distinct(ports))
    ])
    error_message = "Duplicates are not allowed in the list of ports for a given VM"
  }
}

## optional overrides

variable "k8s_pod_cidr" {
  description = "The CIDR range for the Kubernetes pods."
  type        = string
  default     = "192.168.0.0/16"
}

variable "k8s_subnet_cidr" {
  description = "The CIDR range for the Kubernetes subnet."
  type        = string
  default     = "10.0.0.0/24"
}

variable "k8s_version" {
  description = "The version of Kubernetes to install (e.g., 1.32, 1.34)."
  type        = string
  default     = "1.32"
}

variable "machine_type" {
  description = "The machine type for both control plane and worker nodes."
  type        = string
  default     = "e2-standard-4"
}

variable "os_image" {
  description = "The boot image for the instances."
  type        = string
  default     = "debian-cloud/debian-13"
}

variable "region" {
  description = "The GCP region for deployment."
  type        = string
  default     = "us-central1"
}

variable "unix_user" {
  description = "The Unix username to create on VMs for injected SSH keys."
  type        = string
  default     = "admin"
}

variable "worker_node_count" {
  description = "The number of worker nodes to provision."
  type        = number
  default     = 1

  validation {
    condition     = var.worker_node_count >= 1 && var.worker_node_count <= 253
    error_message = "worker_node_count must be between 1 and 253 because kubeadm natively allocates a /24 (254 addresses) per node, and we are using a 192.168.0.0/16 cluster CIDR."
  }
}

resource "random_id" "rand" {
  byte_length = 4
}

locals {
  zone        = "${var.region}-a"
  rand_suffix = random_id.rand.hex
}
