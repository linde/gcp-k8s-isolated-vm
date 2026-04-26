#!/bin/bash

#  TODO: make this script unnecessary with a more robust tf destroy teardown

# This script finds and deletes GCP resources associated with the k8s network
# that were created by Kubernetes (e.g. via Cloud Controller Manager) and thus
# prevent Terraform from cleanly destroying the network.

PROJECT=$(grep -oP 'gcp_project\s*=\s*"\K[^"]+' terraform.tfvars 2>/dev/null)

if [ -z "$PROJECT" ]; then
    PROJECT=$(gcloud config get-value project 2>/dev/null)
fi

if [ -z "$PROJECT" ]; then
    echo "Error: Could not determine GCP project."
    exit 1
fi

echo "Using GCP Project: $PROJECT"


# Find the k8s network name (assuming it starts with k8s-network-)
NETWORK=$(gcloud compute networks list --project="$PROJECT" --filter="name ~ ^k8s-network-" --format="value(name)" | head -n 1)

if [ -z "$NETWORK" ]; then
    echo "No network starting with 'k8s-network-' found in project $PROJECT."
    exit 0
fi

echo "Found network: $NETWORK"

echo "Looking for firewalls to delete..."
FIREWALLS=$(gcloud compute firewall-rules list --project="$PROJECT" --filter="network:$NETWORK" --format="value(name)")

for fw in $FIREWALLS; do
    echo "Deleting firewall: $fw"
    gcloud compute firewall-rules delete "$fw" --project="$PROJECT" --quiet
done

echo "Looking for forwarding rules to delete..."
# Forwarding rules depend on target pools or backend services, usually created for LoadBalancers
FORWARDING_RULES=$(gcloud compute forwarding-rules list --project="$PROJECT" --format="value(name)")

for rule in $FORWARDING_RULES; do
    # Double check if it belongs to our network (often they are global or regional but we can just try to filter or delete likely ones)
    if [[ "$rule" == a* ]] || [[ "$rule" == k8s* ]]; then
        echo "Deleting forwarding rule: $rule"
        # Need region for forwarding rules usually, let's check if we can get region
        REGION=$(gcloud compute forwarding-rules describe "$rule" --project="$PROJECT" --format="value(region)" 2>/dev/null | awk -F/ '{print $NF}')
        if [ -n "$REGION" ]; then
            gcloud compute forwarding-rules delete "$rule" --project="$PROJECT" --region="$REGION" --quiet
        else
            gcloud compute forwarding-rules delete "$rule" --project="$PROJECT" --global --quiet 2>/dev/null
        fi
    fi
done

echo "Looking for target pools to delete..."
TARGET_POOLS=$(gcloud compute target-pools list --project="$PROJECT" --format="value(name)")

for pool in $TARGET_POOLS; do
    if [[ "$pool" == a* ]] || [[ "$pool" == k8s* ]]; then
        echo "Deleting target pool: $pool"
        REGION=$(gcloud compute target-pools describe "$pool" --project="$PROJECT" --format="value(region)" 2>/dev/null | awk -F/ '{print $NF}')
        if [ -n "$REGION" ]; then
             gcloud compute target-pools delete "$pool" --project="$PROJECT" --region="$REGION" --quiet
        fi
    fi
done

echo "Waiting 10 seconds for resources to release..."
sleep 10

echo "Looking for addresses to delete..."
# Addresses can block subnetwork deletion
ADDRESSES=$(gcloud compute addresses list --project="$PROJECT" --format="value(name)")

for addr in $ADDRESSES; do
    if [[ "$addr" == *"-ip-"* ]] || [[ "$addr" == k8s* ]] || [[ "$addr" == httpbin* ]]; then
        echo "Deleting address: $addr"
        REGION=$(gcloud compute addresses describe "$addr" --project="$PROJECT" --format="value(region)" 2>/dev/null | awk -F/ '{print $NF}')
        
        # Retry loop (up to 10 attempts with 10 sec sleep)
        attempt=1
        success=false
        while [ $attempt -le 10 ]; do
            echo "Attempt $attempt at deleting address $addr..."
            if [ -n "$REGION" ]; then
                if gcloud compute addresses delete "$addr" --project="$PROJECT" --region="$REGION" --quiet; then
                    success=true
                    break
                fi
            else
                if gcloud compute addresses delete "$addr" --project="$PROJECT" --global --quiet 2>/dev/null; then
                    success=true
                    break
                fi
            fi
            echo "Delete failed, waiting 10 seconds before retry..."
            sleep 10
            attempt=$((attempt + 1))
        done
        
        if [ "$success" = false ]; then
             echo "Failed to delete address $addr after 3 attempts."
        fi
    fi
done

echo "Looking for routes to delete..."
# Ignore routes created by terraform (pod-cidr-*) and default routes
ROUTES=$(gcloud compute routes list --project="$PROJECT" --filter="network:$NETWORK AND NOT name ~ ^pod-cidr-" --format="value(name)")

for route in $ROUTES; do
    # Check if it's a default route to avoid deleting internet gateway routes if they are needed, but usually terraform recreates them or we just want to delete k8s routes
    if [[ "$route" == default* ]]; then
        continue
    fi
    echo "Deleting route: $route"
    gcloud compute routes delete "$route" --project="$PROJECT" --quiet
done

echo "Cleanup complete."
