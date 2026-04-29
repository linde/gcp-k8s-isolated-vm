variable "os_image" {
  type        = string
  default     = "debian-cloud/debian-13"
  description = "The boot image for the external proxied instance."
}

variable "proxied_vms" {
  type        = map(list(number))
  description = "Map of proxied VM names to their exposed ports."
  default = {
    "httpbin1" = [8080]
    "httpbin2" = [8080, 8888]
  }
}

variable "unix_user" {
  type        = string
  default     = "admin"
  description = "The admin user for SSH access to VMs."
}

