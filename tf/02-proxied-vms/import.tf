data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "${path.module}/../01-base-cluster/terraform.tfstate"
  }
}
