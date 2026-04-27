terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../01-base-cluster/terraform.tfstate"
  }
}

provider "kubernetes" {
  config_path = data.terraform_remote_state.base.outputs.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = data.terraform_remote_state.base.outputs.kubeconfig_path
  }
}

resource "terraform_data" "gateway_api_crds" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=${data.terraform_remote_state.base.outputs.kubeconfig_path} apply --server-side --force-conflicts -f ../../.tmp/standard-install.yaml"
  }
}

resource "helm_release" "agentgateway_crds" {
  name       = "agentgateway-crds"
  repository = "oci://cr.agentgateway.dev/charts"
  chart      = "agentgateway-crds"
  namespace  = "agentgateway-system"
  create_namespace = true
  version    = "v1.1.0"

  depends_on = [terraform_data.gateway_api_crds]
}

resource "helm_release" "agentgateway" {
  name       = "agentgateway"
  repository = "oci://cr.agentgateway.dev/charts"
  chart      = "agentgateway"
  namespace  = "agentgateway-system"
  version    = "v1.1.0"

  set {
    name  = "controller.extraEnv.KGW_ENABLE_GATEWAY_API_EXPERIMENTAL_FEATURES"
    value = "true"
  }

  set {
    name  = "controller.image.pullPolicy"
    value = "Always"
  }

  wait = true

  depends_on = [helm_release.agentgateway_crds]
}

resource "helm_release" "egress_policy" {
  name       = "egress-policy"
  chart      = "./charts/egress-policy"
  namespace  = "agentgateway-system"

  depends_on = [helm_release.agentgateway]
}

