#!/bin/bash

# Analytics Service Kubernetes Deployment Script
# Usage: ./scripts/deploy_analytics_k8s.sh

set -e

echo "=== Analytics Service Kubernetes Deployment ==="
echo ""

# Check Kubernetes is running
echo "[1/4] Checking Kubernetes cluster..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ Kubernetes cluster is not running!"
    echo "   Please enable Kubernetes in Docker Desktop Settings → Kubernetes"
    echo "   Then try again after the cluster starts."
    exit 1
fi
echo "✅ Kubernetes cluster is running"

# Create namespace if not exists
echo ""
echo "[2/4] Creating helios namespace..."
if kubectl get namespace helios > /dev/null 2>&1; then
    echo "✅ Namespace 'helios' already exists"
else
    kubectl create namespace helios
    echo "✅ Namespace 'helios' created"
fi

# Deploy analytics service
echo ""
echo "[3/4] Deploying analytics service..."
kubectl apply -f kubernetes/services/04-analytics-service/
echo "✅ Analytics service deployed"

# Wait for pods to be ready
echo ""
echo "[4/4] Waiting for pods to be ready..."
echo "   This may take 1-2 minutes..."
kubectl wait --for=condition=ready pod -l component=analytics-service -n helios --timeout=300s || true

# Show deployment status
echo ""
echo "=== Deployment Summary ==="
kubectl get deployments -n helios
echo ""
echo "=== Pod Status ==="
kubectl get pods -n helios -l component=analytics-service
echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "  1. Port forward: kubectl port-forward -n helios svc/analytics-service 8000:8000"
echo "  2. Test API: curl http://localhost:8000/api/outcomes/"
echo "  3. View logs: kubectl logs -n helios -l role=api -f"
