#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------
# Helios RTB Engine - Phase 1 Verification Script (Idempotent)
# -----------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No color

echo -e "${GREEN}=== Helios Phase 1 Verification Script ===${NC}"

# Helper function for safe conditional execution
exists_in_minikube() {
  local image="$1"
  minikube image ls | grep -q "$image" && return 0 || return 1
}

exists_in_docker() {
  local image="$1"
  docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$image" && return 0 || return 1
}

# 1️⃣ Check prerequisites
echo -e "\n${YELLOW}[1/8] Checking prerequisites...${NC}"
for cmd in docker minikube kubectl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo -e "${RED}❌ $cmd not found!${NC}"; exit 1; }
done
echo -e "${GREEN}✅ All prerequisites available.${NC}"

# 2️⃣ Ensure Minikube is running
echo -e "\n${YELLOW}[2/8] Checking Minikube status...${NC}"
if ! minikube status | grep -q "host: Running"; then
  echo -e "${YELLOW}Starting Minikube...${NC}"
  minikube start
else
  echo -e "${GREEN}✅ Minikube already running.${NC}"
fi

# 3️⃣ Build or reuse Docker images
echo -e "\n${YELLOW}[3/8] Verifying Docker images...${NC}"

cd ../../..
cd helios-rtb-engine/services

# Bid Request Handler
if exists_in_docker "helios/bid-request-handler:phase1"; then
  echo -e "${GREEN}✔ Image helios/bid-request-handler:phase1 already exists — skipping build.${NC}"
else
  echo -e "${YELLOW}Building helios/bid-request-handler:phase1...${NC}"
  cd bid-request-handler
  docker build -t helios/bid-request-handler:phase1 .
  cd ..
fi

# Bidding Logic Service
if exists_in_docker "helios/bidding-logic-service:phase1"; then
  echo -e "${GREEN}✔ Image helios/bidding-logic-service:phase1 already exists — skipping build.${NC}"
else
  echo -e "${YELLOW}Building helios/bidding-logic-service:phase1...${NC}"
  cd bidding-logic-service
  docker build -t helios/bidding-logic-service:phase1 .
  cd ..
fi

echo -e "${GREEN}✅ Docker images ready.${NC}"

# 4️⃣ Load images into Minikube (if not already loaded)
echo -e "\n${YELLOW}[4/8] Loading images into Minikube...${NC}"
for img in helios/bid-request-handler:phase1 helios/bidding-logic-service:phase1; do
  if exists_in_minikube "$img"; then
    echo -e "${GREEN}✔ Image $img already present in Minikube.${NC}"
  else
    echo -e "${YELLOW}Loading $img into Minikube...${NC}"
    minikube image load "$img"
  fi
done

echo -e "${GREEN}✅ Minikube images ready.${NC}"

# 5️⃣ Apply Kubernetes manifests (idempotent: kubectl apply is safe)
echo -e "\n${YELLOW}[5/8] Deploying Kubernetes manifests...${NC}"
cd ../kubernetes
kubectl apply -f 00-namespace.yaml
kubectl apply -f infra/configmap.yaml
kubectl apply -f infra/kafka/zookeeper.yaml
kubectl apply -f infra/kafka/cluster.yaml
kubectl apply -f services/01-bid-request-handler/deployment.yaml
kubectl apply -f services/01-bid-request-handler/service.yaml
kubectl apply -f services/03-bidding-logic-service/deployment.yaml

echo -e "${GREEN}✅ Manifests applied.${NC}"

# 6️⃣ Wait for all pods in helios namespace
echo -e "\n${YELLOW}[6/8] Waiting for pods to become ready...${NC}"
kubectl wait --for=condition=Ready pods --all -n helios --timeout=180s || {
  echo -e "${RED}❌ Some pods did not become ready in time.${NC}"
  kubectl get pods -n helios
  exit 1
}
kubectl get pods -n helios
echo -e "${GREEN}✅ All pods running.${NC}"

# 7️⃣ Test bid request
echo -e "\n${YELLOW}[7/8] Sending test bid request...${NC}"
kubectl -n helios port-forward svc/bid-request-handler-service 8080:80 >/dev/null 2>&1 &
PF_PID=$!
sleep 5

# pwd
cd ../scripts/
RESPONSE=$(python3 generate_data.py | head -n 1 | curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8080/bid -H "Content-Type: application/json" -d @-)

kill $PF_PID >/dev/null 2>&1 || true

if [ "$RESPONSE" == "202" ]; then
  echo -e "${GREEN}✅ Test bid request accepted (HTTP 202).${NC}"
else
  echo -e "${RED}❌ Unexpected response code: $RESPONSE${NC}"
  exit 1
fi

# 8️⃣ Verify bidding logic logs
echo -e "\n${YELLOW}[8/8] Checking bidding logic logs...${NC}"
POD=$(kubectl get pods -n helios -l component=bidding-logic-service -o name | head -n 1)
if kubectl logs -n helios "$POD" | grep -q "Bid request received"; then
  echo -e "${GREEN}✅ Bid request successfully processed.${NC}"
else
  echo -e "${YELLOW}⚠ No 'Bid request received' found in logs yet.${NC}"
fi

echo -e "\n${GREEN}🎉 Phase 1 verification complete (idempotent mode)!${NC}"
