# Phase 2 Verification Checklist (Enriched Profiles)

Validate the user-profile enrichment pipeline after shipping the gRPC client and circuit breaker. Run all commands from `helios-rtb-engine/` unless noted.

---

## 1. Prerequisites

Ensure the following tools are available:

* Docker 24+
* Minikube (or another Kubernetes cluster)
* kubectl 1.29+
* Python 3.12 for helper scripts

Start or verify Minikube:

```bash
minikube status || minikube start
```

---

## 2. Build container images

Regenerate the Python gRPC stubs before rebuilding the services:

```bash
cd services/bidding-logic-service
python3 scripts/generate_user_profile_stubs.py

cd ../user-profile-service
docker build -t helios/user-profile-service:phase2 .

cd ../bidding-logic-service
docker build -t helios/bidding-logic-service:phase2 .

cd ../bid-request-handler
docker build -t helios/bid-request-handler:phase1 .
```

If using Minikube, load the images:

```bash
minikube image load helios/user-profile-service:phase2
minikube image load helios/bidding-logic-service:phase2
minikube image load helios/bid-request-handler:phase1
```

---

## 3. Deploy Kubernetes manifests

```bash
cd ../kubernetes
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

kubectl wait --for=condition=Ready pods --all -n helios --timeout=240s
kubectl get pods -n helios
```

---

## 4. Seed Redis and inspect data

```bash
USER_PROFILE_POD=$(kubectl get pods -n helios -l component=user-profile-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n helios "$USER_PROFILE_POD" -- node dist/seed_redis.js

REDIS_POD=$(kubectl get pods -n helios -l component=redis -o jsonpath='{.items[0].metadata.name}')
USER_ID=$(kubectl exec -n helios "$REDIS_POD" -- sh -c "redis-cli --scan --pattern 'user-*' | awk 'NR==1 {print; exit}'")
kubectl exec -n helios "$REDIS_POD" -- redis-cli GET "$USER_ID"
```

Confirm the stored JSON includes nested `interests` and `demographics` data. Keep the exported `USER_ID` for later steps.

---

## 5. Roll out updated services

```bash
kubectl set image -n helios deployment/user-profile-service-deployment user-profile-service=helios/user-profile-service:phase2
kubectl set image -n helios deployment/bidding-logic-service-deployment bidding-logic-service=helios/bidding-logic-service:phase2
kubectl set env   -n helios deployment/bidding-logic-service-deployment \
	USER_PROFILE_SVC_ADDR=user-profile-service.helios.svc.cluster.local:50051 \
	USER_PROFILE_SVC_TIMEOUT=2.0

kubectl rollout status -n helios deployment/user-profile-service-deployment
kubectl rollout status -n helios deployment/bidding-logic-service-deployment
```

---

## 6. Send a test bid request

```bash
kubectl -n helios port-forward svc/bid-request-handler-service 8080:80 >/tmp/helios-pf.log 2>&1 &
PF_PID=$!
sleep 5

cd ../scripts
PAYLOAD=$(python3 generate_data.py | head -n 1)
ENRICHED_PAYLOAD=$(python3 - "$USER_ID" <<'PY'
import json, sys
payload = json.loads(sys.stdin.read())
payload["user_id"] = sys.argv[1]
print(json.dumps(payload))
PY
<<<"$PAYLOAD")

HTTP_CODE=$(printf '%s' "$ENRICHED_PAYLOAD" | curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8080/bid -H "Content-Type: application/json" -d @-)
kill "$PF_PID" >/dev/null 2>&1 || true

test "$HTTP_CODE" = "202"
```

The request should return HTTP 202.

---

## 7. Verify enriched logs

```bash
BLS_POD=$(kubectl get pods -n helios -l component=bidding-logic-service -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n helios "$BLS_POD" --since=5m | grep '"enriched_profile"'
```

Expect output resembling:

```json
"enriched_profile": {
	"profile": {
		"user_id": "user-123",
		"locale": "en-US",
		"interests": [
			{ "category": "sports", "score": 0.95 },
			{ "category": "finance", "score": 0.70 }
		],
		"demographics": { "age_bracket": "35-44" }
	}
}
```

A nested payload confirms successful gRPC enrichment.

---

## 8. Exercise the circuit breaker

```bash
kubectl delete pods -n helios -l component=user-profile-service --ignore-not-found
sleep 5

kubectl -n helios port-forward svc/bid-request-handler-service 8080:80 >/tmp/helios-pf.log 2>&1 &
PF_PID=$!
sleep 5
printf '%s' "$ENRICHED_PAYLOAD" | curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8080/bid -H "Content-Type: application/json" -d @-
kill "$PF_PID" >/dev/null 2>&1 || true

kubectl logs -n helios "$BLS_POD" --since=2m | grep -E "User profile (RPC failed|circuit breaker open)"
kubectl rollout status -n helios deployment/user-profile-service-deployment
```

The bidding logic service should continue processing Kafka messages while logging the gRPC failure and circuit breaker activity. Once complete, verify the user-profile deployment has recovered.

---

✅ Tip: Run `docs/testing/phase2_verify.sh` for an idempotent automation of these steps.
