#!/bin/bash
###############################################################################
# Post-Deployment Script - Fix CoreDNS for Fargate
###############################################################################
# This script patches CoreDNS to run on Fargate nodes by adding the required
# toleration. This is necessary because Fargate nodes have a taint that 
# prevents pods from scheduling unless they explicitly tolerate it.
###############################################################################

set -e

echo "=========================================="
echo "Post-Deployment Fix: CoreDNS for Fargate"
echo "=========================================="

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: kubectl is not configured or cannot reach the cluster"
    echo "Please run: aws eks update-kubeconfig --region <region> --name <cluster-name>"
    exit 1
fi

echo ""
echo "Checking CoreDNS deployment status..."
COREDNS_PENDING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[*].status.phase}' | grep -o "Pending" | wc -l || true)

if [ "$COREDNS_PENDING" -gt 0 ]; then
    echo "⚠️  CoreDNS pods are in Pending state. Applying fix..."
    
    # Create temporary patch file
    cat > /tmp/coredns-fargate-patch.yaml << 'EOF'
spec:
  template:
    spec:
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/control-plane
      - key: CriticalAddonsOnly
        operator: Exists
      - key: eks.amazonaws.com/compute-type
        operator: Equal
        value: fargate
        effect: NoSchedule
EOF
    
    echo "Patching CoreDNS deployment..."
    kubectl patch deployment coredns -n kube-system --patch-file /tmp/coredns-fargate-patch.yaml
    
    echo "Waiting for CoreDNS pods to be ready..."
    kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s || true
    
    rm -f /tmp/coredns-fargate-patch.yaml
    
    echo "✅ CoreDNS fix applied successfully!"
else
    echo "✅ CoreDNS pods are already running. No fix needed."
fi

echo ""
echo "Current CoreDNS pod status:"
kubectl get pods -n kube-system -l k8s-app=kube-dns

echo ""
echo "=========================================="
echo "Post-deployment fix completed!"
echo "=========================================="
