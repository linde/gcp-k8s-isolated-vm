terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.23.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    ssh = {
      source = "loafoe/ssh"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}


provider "google" {
  project = data.terraform_remote_state.base.outputs.gcp_project
  region  = data.terraform_remote_state.base.outputs.region
}

provider "kubernetes" {
  config_path = data.terraform_remote_state.base.outputs.kubeconfig_path
}
