output "proxied_vm_ip" {
  value       = google_compute_address.proxied_vm_ip.address
  description = "The internal IP of the proxied VM."
}

output "ipsec_psk" {
  value       = random_password.ipsec_psk.result
  description = "The auto-generated IPsec pre-shared key."
  sensitive   = true
}
