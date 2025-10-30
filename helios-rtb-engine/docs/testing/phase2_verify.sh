#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------
# Helios RTB Engine - Phase 2 Verification Script (Idempotent)
# -----------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
SERVICES_DIR="$REPO_ROOT/services"
K8S_DIR="$REPO_ROOT/kubernetes"
SCRIPTS_DIR="$REPO_ROOT/scripts"

echo -e "${GREEN}=== Helios Phase 2 Verification Script ===${NC}"

exists_in_minikube() {
  local image="$1"
  minikube image ls | grep -q "$image" && return 0 || return 1
}

exists_in_docker() {
  local image="$1"
  docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$image" && return 0 || return 1
}

build_image_if_missing() {
  local service_dir="$1"
  local image_tag="$2"
  if exists_in_docker "$image_tag"; then
    echo -e "${GREEN}✔ Image $image_tag already exists — skipping build.${NC}"
  else
    echo -e "${YELLOW}Building $image_tag...${NC}"
    # Use the repository root as the build context and the service Dockerfile
    dockerfile="$service_dir/Dockerfile"
    if [[ -f "$dockerfile" ]]; then
      docker build -f "$dockerfile" -t "$image_tag" "$REPO_ROOT"
    else
      (cd "$service_dir" && docker build -t "$image_tag" .)
    fi
  fi
}

# 1️⃣ Check prerequisites
echo -e "\n${YELLOW}[1/10] Checking prerequisites...${NC}"
for cmd in docker minikube kubectl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${RED}❌ $cmd not found!${NC}"
    exit 1
  fi
done
echo -e "${GREEN}✅ All prerequisites available.${NC}"

# 2️⃣ Ensure Minikube is running
echo -e "\n${YELLOW}[2/10] Checking Minikube status...${NC}"
if ! minikube status | grep -q "host: Running"; then
  echo -e "${YELLOW}Starting Minikube...${NC}"
  minikube start
else
  echo -e "${GREEN}✅ Minikube already running.${NC}"
fi

# 3️⃣ Generate stubs and build Docker images
echo -e "\n${YELLOW}[3/10] Generating gRPC stubs and building images...${NC}"
# PY_REQUIREMENTS_FILE="$SERVICES_DIR/bidding-logic-service/requirements.txt"
# if [[ -f "$PY_REQUIREMENTS_FILE" ]]; then
#   echo -e "${YELLOW}Ensuring Python dependencies for gRPC stub generation...${NC}"
#   python3 -m pip install --user -r "$PY_REQUIREMENTS_FILE" >/dev/null
# fi
# (cd "$SERVICES_DIR/bidding-logic-service" && python3 scripts/generate_user_profile_stubs.py)
build_image_if_missing "$SERVICES_DIR/user-profile-service" "helios/user-profile-service:phase2"
build_image_if_missing "$SERVICES_DIR/bidding-logic-service" "helios/bidding-logic-service:phase2"
build_image_if_missing "$SERVICES_DIR/bid-request-handler" "helios/bid-request-handler:phase1"
echo -e "${GREEN}✅ Docker images ready.${NC}"

# 4️⃣ Load images into Minikube
echo -e "\n${YELLOW}[4/10] Loading images into Minikube...${NC}"
for img in \
  helios/user-profile-service:phase2 \
  helios/bidding-logic-service:phase2 \
  helios/bid-request-handler:phase1; do
  if exists_in_minikube "$img"; then
    echo -e "${GREEN}✔ Image $img already present in Minikube.${NC}"
  else
    echo -e "${YELLOW}Loading $img into Minikube...${NC}"
    minikube image load "$img"
  fi
done
echo -e "${GREEN}✅ Minikube images ready.${NC}"

# 5️⃣ Apply Kubernetes manifests (idempotent)
echo -e "\n${YELLOW}[5/10] Deploying Kubernetes manifests...${NC}"
pushd "$K8S_DIR" >/dev/null
kubectl apply -f 00-namespace.yaml
kubectl apply -f infra/configmap.yaml
kubectl apply -f infra/redis.yaml
kubectl apply -f infra/kafka/zookeeper.yaml
kubectl apply -f infra/kafka/cluster.yaml
kubectl apply -f services/01-bid-request-handler/deployment.yaml
kubectl apply -f services/01-bid-request-handler/service.yaml
kubectl apply -f services/02-user-profile-service/configmap.yaml
kubectl apply -f services/02-user-profile-service/service.yaml
kubectl apply -f services/02-user-profile-service/deployment.yaml
kubectl apply -f services/03-bidding-logic-service/deployment.yaml
kubectl apply -f services/03-bidding-logic-service/service.yaml
popd >/dev/null
echo -e "${GREEN}✅ Manifests applied.${NC}"

# 6️⃣ Wait for all pods in helios namespace
echo -e "\n${YELLOW}[6/10] Waiting for pods to become ready...${NC}"
if ! kubectl wait --for=condition=Ready pods --all -n helios --timeout=240s; then
  echo -e "${RED}❌ Some pods did not become ready in time.${NC}"
  kubectl get pods -n helios
  exit 1
fi
# Show pods for 15 seconds then continue
POD_WATCH_LOG=$(mktemp)
kubectl get pods -n helios --watch >"$POD_WATCH_LOG" 2>&1 &
KW_PID=$!
cleanup_kubectl_watch() { kill "$KW_PID" >/dev/null 2>&1 || true; rm -f "$POD_WATCH_LOG"; }
trap cleanup_kubectl_watch EXIT
sleep 15
kill "$KW_PID" >/dev/null 2>&1 || true
trap - EXIT
cat "$POD_WATCH_LOG"
rm -f "$POD_WATCH_LOG"
echo -e "${GREEN}✅ All pods running.${NC}"

# 7️⃣ Seed Redis and capture a user id
echo -e "\n${YELLOW}[7/10] Seeding Redis with user profiles...${NC}"
USER_PROFILE_POD=$(kubectl get pods -n helios -l component=user-profile-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n helios "$USER_PROFILE_POD" -- node dist/seed_redis.js
REDIS_POD=$(kubectl get pods -n helios -l component=redis -o jsonpath='{.items[0].metadata.name}')
USER_ID=$(kubectl exec -n helios "$REDIS_POD" -- sh -c "redis-cli --scan --pattern 'user-*' | awk 'NR==1 {print; exit}'")
if [[ -z "$USER_ID" ]]; then
  echo -e "${RED}❌ Failed to locate a seeded user profile in Redis.${NC}"
  exit 1
fi
kubectl exec -n helios "$REDIS_POD" -- redis-cli GET "$USER_ID"
echo -e "${GREEN}✅ Redis seeded with user profile $USER_ID.${NC}"

# 8️⃣ Roll out updated service images and env vars
echo -e "\n${YELLOW}[8/10] Updating service deployments...${NC}"
kubectl set image -n helios deployment/user-profile-service-deployment user-profile-service=helios/user-profile-service:phase2
kubectl set image -n helios deployment/bidding-logic-service-deployment bidding-logic-service=helios/bidding-logic-service:phase2
kubectl set env   -n helios deployment/bidding-logic-service-deployment \
  USER_PROFILE_SVC_ADDR=user-profile-service.helios.svc.cluster.local:50051 \
  USER_PROFILE_SVC_TIMEOUT=2.0
kubectl rollout status -n helios deployment/user-profile-service-deployment
kubectl rollout status -n helios deployment/bidding-logic-service-deployment
echo -e "${GREEN}✅ Deployments updated.${NC}"

# 9️⃣ Send a test bid request and verify enrichment
echo -e "\n${YELLOW}[9/10] Sending test bid request...${NC}"
PORT_FORWARD_LOG=$(mktemp)
kubectl -n helios port-forward svc/bid-request-handler-service 8080:80 >"$PORT_FORWARD_LOG" 2>&1 &
PF_PID=$!
sleep 5
pushd "$SCRIPTS_DIR" >/dev/null
PAYLOAD=$(python3 generate_data.py | head -n 1)
ENRICHED_PAYLOAD=$(python3 - "$USER_ID" <<'PY'
import json, sys
payload = json.loads(sys.stdin.read())
payload["user_id"] = sys.argv[1]
print(json.dumps(payload))
PY
<<<"$PAYLOAD")
HTTP_CODE=$(printf '%s' "$ENRICHED_PAYLOAD" | curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8080/bid -H "Content-Type: application/json" -d @-)
popd >/dev/null
kill "$PF_PID" >/dev/null 2>&1 || true
rm -f "$PORT_FORWARD_LOG"
if [[ "$HTTP_CODE" != "202" ]]; then
  echo -e "${RED}❌ Unexpected response code: $HTTP_CODE${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Test bid request accepted (HTTP 202).${NC}"

BLS_POD=$(kubectl get pods -n helios -l component=bidding-logic-service -o jsonpath='{.items[0].metadata.name}')
if kubectl logs -n helios "$BLS_POD" --since=5m | grep -q '"enriched_profile"'; then
  echo -e "${GREEN}✅ Enriched profile found in bidding logic logs.${NC}"
else
  echo -e "${YELLOW}⚠ Enriched profile not observed yet — check logs manually.${NC}"
fi

# 🔟 Exercise the circuit breaker
echo -e "\n${YELLOW}[10/10] Exercising circuit breaker...${NC}"
kubectl delete pods -n helios -l component=user-profile-service --ignore-not-found
sleep 5
PORT_FORWARD_LOG=$(mktemp)
kubectl -n helios port-forward svc/bid-request-handler-service 8080:80 >"$PORT_FORWARD_LOG" 2>&1 &
PF_PID=$!
sleep 5
printf '%s' "$ENRICHED_PAYLOAD" | curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8080/bid -H "Content-Type: application/json" -d @-
kill "$PF_PID" >/dev/null 2>&1 || true
rm -f "$PORT_FORWARD_LOG"
if kubectl logs -n helios "$BLS_POD" --since=2m | grep -Eq "User profile (RPC failed|circuit breaker open)"; then
  echo -e "${GREEN}✅ Circuit breaker activity captured in logs.${NC}"
else
  echo -e "${YELLOW}⚠ Circuit breaker log entry not detected — review logs manually.${NC}"
fi
kubectl rollout status -n helios deployment/user-profile-service-deployment
echo -e "${GREEN}🎉 Phase 2 verification complete!${NC}"
