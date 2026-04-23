variable "gcp_project" {
  type        = string
  description = "The GCP project ID to deploy into."
}

variable "region" {
  type        = string
  description = "The GCP region for deployment."
}

variable "zone" {
  type        = string
  description = "The GCP zone for deployment."
}

variable "network_id" {
  type        = string
  description = "The IDs of the VPC network."
}

variable "subnetwork_id" {
  type        = string
  description = "The ID of the VPC subnetwork."
}

variable "os_image" {
  type        = string
  description = "The boot image for the proxied VM."
}

variable "worker_node_ip" {
  type        = string
  description = "The IP of the worker node acting as the Geneve tunnel endpoint."
}

variable "proxied_ports" {
  type        = list(number)
  description = "List of network ports to expose and proxy to the VM."
}



variable "name_suffix" {
  type        = string
  default     = ""
  description = "Optional suffix to append to resource names for uniqueness."
}

variable "name_prefix" {
  type        = string
  default     = "proxied-vm"
  description = "Prefix for the proxied VM resource names."
}

variable "tunnel_id" {
  type        = number
  default     = 100
  description = "The Geneve tunnel ID and third octet for the overlay subnet."
}

variable "ssh_public_key" {
  type        = string
  description = "The public SSH key to authorize on the proxied VM."
}

variable "static_ip" {
  type        = string
  description = "The pre-allocated static internal IP for the proxied VM."
}


