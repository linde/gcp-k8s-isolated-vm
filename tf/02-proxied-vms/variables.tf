variable "os_image" {
  type        = string
  default     = "debian-cloud/debian-13"
  description = "The boot image for the external proxied instance."
}

variable "proxied_vms" {
  type = map(list(number))
  default = {
    httpbin1 = [80, 8080]
    httpbin2 = [8888]
  }
  description = "Mapping of VM name prefixes to lists of exposed ports. Note: the ports might land on a single node, so they must be unique across all proxied_vms"
}



