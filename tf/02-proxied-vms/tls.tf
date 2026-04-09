# Generate local CA
resource "tls_private_key" "ca" {
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "geneve-tunnel-ca"
    organization = "Linde Corp Architecture"
  }

  validity_period_hours = 8760 # 1 year
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# Proxy Pod Certificate (Client/Server)
resource "tls_private_key" "proxy" {
  algorithm = "ED25519"
}

resource "tls_cert_request" "proxy" {
  private_key_pem = tls_private_key.proxy.private_key_pem

  subject {
    common_name = "proxy-pod.geneve.internal"
  }
}

resource "tls_locally_signed_cert" "proxy" {
  cert_request_pem   = tls_cert_request.proxy.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# Isolated VM Certificate (Client/Server)
resource "tls_private_key" "vm" {
  algorithm = "ED25519"
}

resource "tls_cert_request" "vm" {
  private_key_pem = tls_private_key.vm.private_key_pem

  subject {
    common_name = "isolated-vm.geneve.internal"
  }
}

resource "tls_locally_signed_cert" "vm" {
  cert_request_pem   = tls_cert_request.vm.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "vm_ssh_key" {
  algorithm   = "ED25519"
}
