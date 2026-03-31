# Cloud K8s Scratch with Envoy Proxied Pod

This Terraform project provisions a Kubernetes cluster on GCP instances (using `kubeadm`), alongside an `e2-micro` VM that connects to the cluster via an Envoy proxied pod.

## Architecture

The system uses a hybrid approach for the Proxied VM:
- **Inbound**: Traditional Kubernetes Ingress/NodePort -> Envoy Pod -> Proxied VM (Port 80)
- **Outbound (Egress)**: Transparent Layer 3 VPC Routing (VM -> Worker Node NAT -> Internet)

### Layer 3 VPC Routing Architecture Components and their contributions

- **Proxied VM**: Tagged with a specific via-node tag (e.g., `proxied-vm-via-node-1-xyz`), runs standard applications. No proxy environment variables are needed.
- **GCP VPC Static Route**: Points `0.0.0.0/0` (internet egress) from tagged instances to the Worker Node as the next hop.
- **Kubernetes Worker Node**: Acting as a transparent NAT gateway using standard `iptables` MASQUERADE rules.
- **Envoy Pod**: Still handles inbound requests from the cluster to the Proxied VM.

## Getting Started

Follow these steps to deploy and test the infrastructure.

### 1. Provision Infrastructure

Apply the Terraform configuration to provision the GCP VMs (Control Plane, Worker, and Proxied VM) and generate the Kubernetes manifests.

```bash
cat <<EOF > terraform.tfvars
# this is the only required variable
gcp_project = "project-name"
# override other variables here too
EOF

terraform init
terraform apply
```

### 2. Deploy the Proxied Pod

Once the cluster is up and running, extract the Control Plane IP and fetch the `kubeconfig` to your local `.tmp` directory to interact with the cluster. *Note: The `terraform apply` step will generate `.tmp/proxied-pod.yaml` containing the K8s manifests configured with the VM's static IP.*

```bash

export CP_IP=$(terraform output -raw control_plane_public_ip)
export SSH_KEY=$(terraform output -raw ssh_key_path)
export KUBECONFIG="$(pwd)/.tmp/kubeconfig.yaml"

export SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${SSH_KEY}"

# you can watch the control plane boot with:
ssh ${SSH_OPTS} admin@${CP_IP} "sudo journalctl  -u google-startup-scripts.service -f " 

# then get a kubeconfig for the host:
ssh ${SSH_OPTS} admin@${CP_IP} "sudo cat /etc/kubernetes/admin.conf" > ${KUBECONFIG}

kubectl apply -f .tmp/proxied-pod.yaml
```

### 3. Verify the Deployment

Verify that the `proxied-pod` is running successfully:

```bash
kubectl get pods
kubectl get svc proxied-svc
```

### 4. Test the Bridge (Layer 3 Egress)

The `e2-micro` VM is running an inline Python script that serves HTTP requests on port `80`. When it receives a `GET` request, it synchronously tests direct internet egress by calling `httpbin.org/ip`.

To test the entire inbound/outbound flow, use `kubectl port-forward` to hit the service directly:

1. Start port-forwarding in the background (or in a separate terminal):
   ```bash
   kubectl port-forward svc/proxied-svc 8080:80 &
   ```
2. Send a request to the forwarded port:
   ```bash
   curl http://localhost:8080
   ```

**Expected output:**
A successful JSON response indicating the Python script on the VM received your request AND successfully hits `httpbin.org/ip` transparently via Layer 3 routing! The `origin_ip` returned will be the public IP of the Kubernetes worker node (not the proxied VM's ephemeral/private IP).

```json
{"message": "Successfully hit httpbin via direct L3 routing", "origin_ip": "34.135.217.180", "httpbin_status": 200}
```
