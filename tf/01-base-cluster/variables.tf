
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

## NB: 
variable "proxied_vms" {
  type        = map(list(number))
  default     = {
    httpbin1 = [80, 8080]
    httpbin2 = [8888]
  }
  description = "Mapping of VM name prefixes to lists of exposed ports. Note: the ports might land on a single node, so they must be unique across all proxied_vms"

  validation {
    condition     = length(flatten(values(var.proxied_vms))) == length(distinct(flatten(values(var.proxied_vms))))
    error_message = "All ports across all proxied_vms must be unique."
  }
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

variable "proxied_vm_ips" {
  type        = list(string)
  default     = ["10.0.0.2", "10.0.0.3"]
  description = "Static IPs of all proxied VMs to target for Geneve tunnels."
}

variable "k8s_pod_cidr" {
  type        = string
  default     = "192.168.0.0/16"
  description = "The CIDR range for the Kubernetes pods."
}

variable "unix_user" {
  type        = string
  default     = "admin"
  description = "The Unix username to create on VMs for injected SSH keys."
}

