data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../01-base-cluster/terraform.tfstate"
  }
}

locals {
  region          = data.terraform_remote_state.base.outputs.region
  gcp_project     = data.terraform_remote_state.base.outputs.gcp_project
  rand_suffix     = data.terraform_remote_state.base.outputs.rand_suffix
  service_account = data.terraform_remote_state.base.outputs.gke_node_service_account_email
}
