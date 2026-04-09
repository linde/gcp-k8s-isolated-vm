# K8s Managed Isolated VM via Geneve Tunnels

This project demonstrates how to manage ingress and egress for isolated VMs that reside outside of a Kubernetes cluster using **Geneve Overlay Tunnels**.

The infrastructure is divided into two peer Terraform projects:
1. **`01-base-cluster`**: Provisions the core GCP VPC network, subnets, firewall rules, and the Kubernetes cluster (one control plane node and worker nodes).
2. **`02-proxied-vms`**: Provisions external, isolated VMs and integrates them securely into the Kubernetes cluster via Geneve tunneling and mutual TLS (mTLS).

## Architecture

In this architecture, the VM integrates into the cluster via a **Geneve Overlay Tunnel** (UDP port 6081). A privileged Proxy Pod sits inside the Kubernetes cluster acting as one end of the tunnel, and the VM acts as the other end.

- **Inbound (Ingress)**: Kubernetes LoadBalancer Service -> Proxy Pod -> Geneve Tunnel -> Proxied VM
- **Outbound (Egress)**: Proxied VM -> Geneve Tunnel -> Proxy Pod (NAT Masquerade) -> Internet

## Getting Started

Follow these steps to provision the base cluster first, followed by the proxied VMs.

### 1. Deploy Base Cluster (`01-base-cluster`)

First, initialize and apply the base cluster configuration to provision the core networking and Kubernetes nodes:

```bash
cd tf/01-base-cluster

cat <<EOF > terraform.tfvars
# required variable
gcp_project = "your-gcp-project-id"
EOF

terraform init
terraform apply
```

Wait for the cluster to finish provisioning.

### 2. Configure Local `kubeconfig`

Once the base cluster is ready, generate your local `kubeconfig` to interact with it:

```bash
# from within ./tf/01-base-cluster
export CP_IP=$(terraform output -raw control_plane_public_ip)
export KUBECONFIG="$(pwd)/../../.tmp/kubeconfig.yaml"
export SSH_KEY=$(terraform output -raw ssh_key_path)
export SSH_OPTS="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${SSH_KEY}"

# Ensure startup scripts are complete on the control plane
ssh ${SSH_OPTS} admin@${CP_IP} "sudo journalctl -u google-startup-scripts.service -f"
# Break out with Ctrl-C when finished

# Download the admin kubeconfig
ssh ${SSH_OPTS} admin@${CP_IP} "sudo cat /etc/kubernetes/admin.conf" > ${KUBECONFIG}
```

### 3. Deploy Proxied VMs (`02-proxied-vms`)

With the base network and cluster active, navigate to the `02-proxied-vms` directory to attach your external workloads:

```bash
cd ../02-proxied-vms

cat <<EOF > terraform.tfvars
gcp_project = "your-gcp-project-id"
EOF

terraform init
terraform apply
```

During `apply`, Terraform will automatically render the required Kubernetes proxy manifests and endpoint configurations to secure the Geneve tunnels with TLS.

### 4. Deploy Proxy Manifests

Finally, deploy the configured proxy pods and load balancer services into the cluster:

```bash
kubectl apply -f ../.tmp/manifests/
```

### 5. Verify Connectivity

Check that the load balancer services acquire an `EXTERNAL-IP`:

```bash
kubectl get svc
```

For example, to set external access for your isolated VMs `httpbin1-svc`:

```bash
export EXTERNAL_IP=$(kubectl get svc httpbin1-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://${EXTERNAL_IP}
```


