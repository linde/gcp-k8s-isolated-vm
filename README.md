# Scratchpad Example: Kubernetes Managed Isolated VM over mTLS Geneve Tunnel

This project is a scratchpad to explore integrating isolated Google Compute Engine (GCE) virtual machines into a Kubernetes cluster using a **Geneve Overlay Tunnel** secured entirely with **mutual TLS (mTLS)**.

## Architecture

The repository has been restructured into two independent Terraform workspaces to cleanly isolate the lifecycle of the base Kubernetes infrastructure from the proxied virtual machines:

### Workspaces:

1. **`tf/01-base-cluster/`**:
   - Manages core networking (VPC, firewalls, internal subnets).
   - Provisions the control plane and worker nodes.
   - Configures local `outputs.tf` to export necessary networking state.

2. **`tf/02-proxied-vms/`**:
   - Ingests variables from the base workspace via `terraform_remote_state`.
   - Generates an infrastructure-managed CA and unique client/server certificates using the `tls` provider (statelessly).
   - Deploys proxy pods and isolated VMs to tunnel inbound payload traffic directly across the cluster over encrypted sockets.

---

## Traffic Flow

- **Inbound (Ingress)**: External client -> Unencrypted LoadBalancer -> Kubernetes Proxy Pod (`socat TCP-LISTEN`) -> Encrypted Geneve Transport (`socat OPENSSL`) -> Target VM Decryption -> Local VM Application Loopback Listener.
- **Outbound (Egress)**: Target VM Application -> Default Gateway over Overlay Interface -> Proxy Pod (NAT/Masquerade) -> Direct Internet Routing.

---

## Getting Started

Deploying the complete environment follows a sequenced application workflow:

### 1. Provision the Base Cluster

First setup some variables in a `terraform.tfvars` file or via params. You can see the available params in `variables.tf`. 

> Note that because we dont do any air traffic control of node ports and vms, you need to ensure that you do not re-use any ports across your `proxied_vms` values. The default shows two vms getting built with two and one different port being exposed respectively.

```bash
cd tf/01-base-cluster

cat <<EOF > terraform.tfvars
gcp_project = "your-gcp-project-id"
EOF
```

Initialize and apply the core infrastructure first:

```bash
terraform init
terraform apply

export CP_IP=$(terraform output -raw control_plane_public_ip)
export SSH_KEY=$(terraform output -raw ssh_key_path)
export KUBECONFIG="$(pwd)/.tmp/kubeconfig.yaml"

export SSH_OPTS="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${SSH_KEY}"

# you can watch the control plane boot with:
ssh ${SSH_OPTS} admin@${CP_IP} "sudo journalctl -u google-startup-scripts.service -f" 

# then get a kubeconfig for the host:
ssh ${SSH_OPTS} admin@${CP_IP} "sudo cat /etc/kubernetes/admin.conf" > ${KUBECONFIG}
```

### 2. Provision the Application Layer (Proxied VMs)

Deploy the unique application micro-VMs secured with mTLS:

```bash
cd ../02-proxied-vms

# Uses the same project ID from the base configuration

terraform init
terraform apply
```

### 3. Apply Generated Manifests to Kubernetes

Terraform automatically renders manifests injected with the pre-shared TLS material into the local repository. Apply them using `kubectl`:

```bash
export KUBECONFIG="$(pwd)/../01-base-cluster/.tmp/kubeconfig.yaml"

kubectl apply -f .tmp/manifests/
```

### 4. Test Connectivity

Find your LoadBalancer public endpoints and confirm traffic securely traverses the tunnel:

```bash
kubectl get svc

# Standard unencrypted queries to test the tunnel loopback translation
curl http://<EXTERNAL-IP>
```
