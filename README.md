# Cloud K8s Scratch with Envoy Shim Pod

This Terraform project provisions a Kubernetes cluster on GCP instances (using `kubeadm`), alongside an `e2-micro` VM that connects to the cluster via an Envoy shim pod.

## Architecture

The detailed architecture of the bidirectional Envoy proxy setup (inbound to the VM, outbound from the VM through Envoy) can be found in [docs/shim-pod-architecture.md](docs/shim-pod-architecture.md).

## Getting Started

Follow these steps to deploy and test the infrastructure.

### 1. Provision Infrastructure

Apply the Terraform configuration to provision the GCP VMs (Control Plane, Worker, and Shim VM) and generate the Kubernetes manifests.

```bash
cat <<EOF > terraform.tfvars
# this is the only required variable
gcp_project = "project-name"
# override other variables here too
EOF

terraform init
terraform apply
```

### 2. Deploy the Shim Pod

Once the cluster is up and running, extract the Control Plane IP and fetch the `kubeconfig` to your local `.tmp` directory to interact with the cluster. *Note: The `terraform apply` step will generate `.tmp/shim-pod.yaml` containing the K8s manifests configured with the VM's static IP.*

```bash

export CP_IP=$(terraform output -raw control_plane_public_ip)
export SSH_KEY_PATH="$(pwd)/.tmp/vm_key"
export KUBECONFIG="$(pwd)/.tmp/kubeconfig.yaml"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${SSH_KEY_PATH} \
   admin@${CP_IP} "sudo cat /etc/kubernetes/admin.conf" > ${KUBECONFIG}

kubectl apply -f .tmp/shim-pod.yaml
```

### 3. Verify the Deployment

Verify that the `shim-pod` is running successfully:

```bash
kubectl get pods
kubectl get svc shim-svc
```

### 4. Test the Bridge

The `e2-micro` VM is running an inline Python script that serves HTTP requests on port `80`. When it receives a `GET` request, it synchronously tests the outbound proxy by calling `httpbin.org`.

To test the entire inbound/outbound flow, use `kubectl port-forward` to hit the service directly:

1. Start port-forwarding in the background (or in a separate terminal):
   ```bash
   kubectl port-forward svc/shim-svc 8080:80 &
   ```
2. Send a request to the forwarded port:
   ```bash
   curl http://localhost:8080
   ```

**Expected output:**
A successful JSON response indicating the Python script on the VM received your request AND successfully proxied a call to `httpbin.org/get` via the Envoy egress port on `31280`.

```json
{"message": "Successfully hit httpbin via proxy", "httpbin_status": 200}
```
