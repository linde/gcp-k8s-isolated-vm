resource "google_compute_network" "k8s" {
  name                    = "k8s-network-${local.rand_suffix}"
  project                 = var.gcp_project
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [time_sleep.wait_for_services]
}

resource "google_compute_subnetwork" "k8s_subnet" {
  name          = "k8s-subnet-${local.rand_suffix}"
  project       = var.gcp_project
  network       = google_compute_network.k8s.id
  region        = var.region
  ip_cidr_range = var.k8s_subnet_cidr
}

resource "google_compute_address" "cp_static_ip" {
  name   = "cp-static-ip-${local.rand_suffix}"
  region = var.region

  depends_on = [time_sleep.wait_for_services]
}

resource "google_compute_address" "proxied_vm_static_ip" {
  for_each     = var.proxied_vms
  name         = "${each.key}-ip-${local.rand_suffix}"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.k8s_subnet.id

  depends_on = [time_sleep.wait_for_services]
}

# Allow ALL internal traffic within the subnet CIDR (all ports/protocols)
resource "google_compute_firewall" "allow_internal_all" {
  name      = "allow-internal-all-${local.rand_suffix}"
  project   = var.gcp_project
  network   = google_compute_network.k8s.id
  direction = "INGRESS"
  priority  = 100

  allow {
    protocol = "all"
  }

  source_ranges = [
    google_compute_subnetwork.k8s_subnet.ip_cidr_range,
    var.k8s_pod_cidr
  ]
}


# Allow SSH and K8s API access from anywhere (for management)
resource "google_compute_firewall" "allow_management" {
  name        = "allow-management-${local.rand_suffix}"
  project     = var.gcp_project
  network     = google_compute_network.k8s.id
  target_tags = ["k8s-cp"]

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
}



# Allow external load balancer HTTP ingress traffic to the K8s worker node instances
resource "google_compute_firewall" "allow_http" {
  name        = "allow-http-${local.rand_suffix}"
  project     = var.gcp_project
  network     = google_compute_network.k8s.id
  target_tags = ["k8s-node"]

  allow {
    protocol = "tcp"
    ports    = [for p in distinct(flatten(values(var.proxied_vms))) : tostring(p)]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Route Pod CIDR via the worker node so the Proxied VM can address the Proxy Pod directly
resource "google_compute_route" "pod_cidr_route" {
  name              = "pod-cidr-${local.rand_suffix}"
  network           = google_compute_network.k8s.id
  dest_range        = var.k8s_pod_cidr
  next_hop_instance = google_compute_instance.worker_node[0].self_link
  priority          = 1000
}


