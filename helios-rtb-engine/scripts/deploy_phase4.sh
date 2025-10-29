#!/bin/bash

# Helios RTB Engine - Phase 4 Deployment Script
# This script deploys the Observability & UI components

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Helios RTB Engine - Phase 4: Observability & UI Deploy   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if namespace exists
if ! kubectl get namespace helios &> /dev/null; then
    print_error "Namespace 'helios' does not exist. Please run Phase 1-3 deployment first."
    exit 1
fi

print_status "Namespace 'helios' found"

# Step 1: Build Docker Images
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Step 1: Building Docker Images"
echo "════════════════════════════════════════════════════════════"

# Build Advertiser Dashboard
echo ""
print_status "Building Advertiser Dashboard image..."
cd services/advertiser-dashboard
docker build -t helios/advertiser-dashboard:phase4 . || {
    print_error "Failed to build advertiser-dashboard image"
    exit 1
}
cd ../..

# Rebuild Bid Request Handler with metrics
echo ""
print_status "Rebuilding Bid Request Handler with metrics..."
cd services/bid-request-handler
docker build -t helios/bid-request-handler:phase4 . || {
    print_error "Failed to build bid-request-handler image"
    exit 1
}
cd ../..

# Rebuild Bidding Logic Service with metrics
echo ""
print_status "Rebuilding Bidding Logic Service with metrics..."
cd services/bidding-logic-service
docker build -t helios/bidding-logic-service:phase4 . || {
    print_error "Failed to build bidding-logic-service image"
    exit 1
}
cd ../..

# Check if using Minikube
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    echo ""
    print_status "Minikube detected - loading images..."
    minikube image load helios/advertiser-dashboard:phase4
    minikube image load helios/bid-request-handler:phase4
    minikube image load helios/bidding-logic-service:phase4
fi

print_status "All images built successfully"

# Step 2: Deploy Gateway
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Step 2: Deploying API Gateway (Traefik)"
echo "════════════════════════════════════════════════════════════"

echo ""
print_status "Installing Traefik CRDs..."
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.0/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml || {
    print_warning "CRDs may already exist, continuing..."
}

echo ""
print_status "Deploying Gateway RBAC..."
kubectl apply -f kubernetes/gateway/rbac.yaml

echo ""
print_status "Deploying Gateway..."
kubectl apply -f kubernetes/gateway/deployment.yaml
kubectl apply -f kubernetes/gateway/service.yaml
kubectl apply -f kubernetes/gateway/ingressroute.yaml

echo ""
print_status "Waiting for Gateway to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/gateway-deployment -n helios || {
    print_error "Gateway deployment failed"
    exit 1
}

print_status "Gateway deployed successfully"

# Step 3: Deploy Monitoring Stack
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Step 3: Deploying Monitoring Stack (Prometheus & Grafana)"
echo "════════════════════════════════════════════════════════════"

echo ""
print_status "Deploying Prometheus..."
kubectl apply -f kubernetes/infra/prometheus-grafana/prometheus.yaml

echo ""
print_status "Waiting for Prometheus to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/prometheus -n helios || {
    print_error "Prometheus deployment failed"
    exit 1
}

echo ""
print_status "Deploying Grafana dashboards..."
kubectl apply -f kubernetes/infra/prometheus-grafana/dashboards.yaml

echo ""
print_status "Deploying Grafana..."
kubectl apply -f kubernetes/infra/prometheus-grafana/grafana.yaml

echo ""
print_status "Waiting for Grafana to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/grafana -n helios || {
    print_error "Grafana deployment failed"
    exit 1
}

print_status "Monitoring stack deployed successfully"

# Step 4: Deploy Advertiser Dashboard
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Step 4: Deploying Advertiser Dashboard"
echo "════════════════════════════════════════════════════════════"

echo ""
print_status "Deploying Dashboard ConfigMap..."
kubectl apply -f kubernetes/services/06-advertiser-dashboard/configmap.yaml

echo ""
print_status "Deploying Dashboard..."
kubectl apply -f kubernetes/services/06-advertiser-dashboard/deployment.yaml
kubectl apply -f kubernetes/services/06-advertiser-dashboard/service.yaml

echo ""
print_status "Waiting for Dashboard to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/advertiser-dashboard-deployment -n helios || {
    print_error "Dashboard deployment failed"
    exit 1
}

print_status "Advertiser Dashboard deployed successfully"

# Step 5: Update Services with Metrics
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Step 5: Updating Services with Metrics"
echo "════════════════════════════════════════════════════════════"

echo ""
print_status "Updating Bid Request Handler..."
kubectl set image deployment/bid-request-handler-deployment \
    bid-request-handler=helios/bid-request-handler:phase4 -n helios

kubectl rollout status deployment/bid-request-handler-deployment -n helios

echo ""
print_status "Updating Bidding Logic Service..."
kubectl set image deployment/bidding-logic-service-deployment \
    bidding-logic-service=helios/bidding-logic-service:phase4 -n helios

kubectl rollout status deployment/bidding-logic-service-deployment -n helios

print_status "Services updated successfully"

# Step 6: Verify Deployment
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Step 6: Verifying Deployment"
echo "════════════════════════════════════════════════════════════"

echo ""
print_status "Checking all pods..."
kubectl get pods -n helios

echo ""
print_status "Checking services..."
kubectl get svc -n helios

echo ""
print_status "Checking IngressRoute..."
kubectl get ingressroute -n helios

# Get Gateway URL
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Access Information"
echo "════════════════════════════════════════════════════════════"

if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    GATEWAY_URL=$(minikube service gateway -n helios --url | head -n 1)
    echo ""
    print_status "Gateway URL (Minikube):"
    echo "  $GATEWAY_URL"
else
    NODE_PORT=$(kubectl get svc gateway -n helios -o jsonpath='{.spec.ports[0].nodePort}')
    echo ""
    print_status "Gateway NodePort: $NODE_PORT"
    print_warning "Access via: http://<node-ip>:$NODE_PORT"
fi

echo ""
echo "Available Endpoints:"
echo "  • Advertiser Dashboard:  \$GATEWAY_URL/"
echo "  • Grafana Dashboard:     \$GATEWAY_URL/grafana"
echo "  • Prometheus UI:         \$GATEWAY_URL/prometheus"
echo "  • Analytics API:         \$GATEWAY_URL/api/outcomes/"
echo "  • Bid Endpoint:          \$GATEWAY_URL/bid"
echo ""
echo "Grafana Credentials:"
echo "  • Username: admin"
echo "  • Password: admin"
echo ""

# Final verification
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Running Health Checks"
echo "════════════════════════════════════════════════════════════"

sleep 5

# Check if pods are healthy
UNHEALTHY_PODS=$(kubectl get pods -n helios --field-selector=status.phase!=Running -o jsonpath='{.items[*].metadata.name}')

if [ -z "$UNHEALTHY_PODS" ]; then
    print_status "All pods are healthy!"
else
    print_warning "Some pods are not in Running state:"
    echo "$UNHEALTHY_PODS"
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Phase 4 Deployment Complete! ✓                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Next Steps:"
echo "  1. Access the Advertiser Dashboard at \$GATEWAY_URL/"
echo "  2. View metrics in Grafana at \$GATEWAY_URL/grafana"
echo "  3. Run verification tests: docs/testing/final-verification.md"
echo "  4. Generate load: ./scripts/generate_load.sh \$GATEWAY_URL 1000"
echo ""
print_status "For detailed verification instructions, see:"
echo "  docs/testing/final-verification.md"
echo ""
