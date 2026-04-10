output "proxied_vm_ip" {
  value       = google_compute_address.proxied_vm_ip.address
  description = "The internal IP of the proxied VM."
}


