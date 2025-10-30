# Phase 1 Verification Checklist (Updated)

Follow this guide to verify that the bid ingestion pipeline works end-to-end.

---

## 1. Prerequisites

Ensure the following are installed and available in your shell:

* Docker 24+
* Minikube (or another Kubernetes cluster)
* kubectl 1.29+ (configured to your cluster)
* Python 3.12 for running helper scripts

Make sure Minikube is running:

```bash
minikube status
```

---

## 2. Build container images

From the repository root:

```bash
cd helios-rtb-engine/services/bid-request-handler
docker build -t helios/bid-request-handler:phase1 .

cd ../bidding-logic-service
docker build -t helios/bidding-logic-service:phase1 .
```

> If using Minikube, load the images into Minikube’s Docker daemon:

```bash
minikube image load helios/bid-request-handler:phase1
minikube image load helios/bidding-logic-service:phase1
```

---

## 3. Deploy Kubernetes manifests

```bash
cd ../../kubernetes
kubectl apply -f 00-namespace.yaml
kubectl apply -f infra/configmap.yaml
kubectl apply -f infra/kafka/zookeeper.yaml
kubectl apply -f infra/kafka/cluster.yaml
kubectl apply -f services/01-bid-request-handler/deployment.yaml
kubectl apply -f services/01-bid-request-handler/service.yaml
kubectl apply -f services/03-bidding-logic-service/deployment.yaml
```

Wait a few seconds for Kubernetes to create the resources.

---

## 4. Confirm pod status

```bash
kubectl get pods -n helios -w
```

Expected:

* `bid-request-handler-deployment` → `Running`
* `bidding-logic-service-deployment` → `Running`
* `kafka-0` → `Running`
* `zookeeper-0` → `Running`

> If `CrashLoopBackOff` occurs for bidding logic service, ensure `six` is installed in `requirements.txt` and the image is rebuilt and loaded into Minikube.

> If Kafka or Zookeeper pods report `ImagePullBackOff`, load the images into Minikube:
>
> ```bash
> minikube image load --overwrite confluentinc/cp-zookeeper:7.5.1
> minikube image load --overwrite confluentinc/cp-kafka:7.5.1
> ```

---

## 5. Port-forward the bid request handler

Open a new terminal window:

```bash
kubectl -n helios port-forward svc/bid-request-handler-service 8080:80
```

The service is now available at `http://localhost:8080`.

---

## 6. Send a test bid request

With port-forward active, run the helper script and send a request:

```bash
cd ../../scripts
python3 generate_data.py | head -n 1 | curl -i -X POST http://localhost:8080/bid -H "Content-Type: application/json" -d @-
```

Expected response:

```
HTTP/1.1 202 Accepted
```

> `head -n 1` ensures only the first JSON line is sent. PowerShell users can use `Select-Object -First 1` instead.

---

## 7. Verify the consumer logs

Identify one of the bidding logic pods:

```bash
kubectl get pods -n helios -l component=bidding-logic-service -o name
```

Stream its logs to confirm the message was processed:

```bash
kubectl logs -f -n helios <pod-name>
```

Sample output (JSON format):

```json
{
  "timestamp":"2025-10-04T17:24:58.123456+00:00",
  "level":"info",
  "message":"Bid request received",
  "fields":{
    "topic":"bid_requests",
    "partition":0,
    "offset":12,
    "value":"{\"id\":\"d9f...\"}"
  }
}
```

Once you see your bid request appear in the logs, **Phase 1 verification is complete**.

---

✅ Notes for future users:

* Ensure Kafka is running and reachable in your cluster (`kafka-service.helios.svc.cluster.local:9092`).
* If the `bidding-logic-service` fails due to `ModuleNotFoundError: kafka.vendor.six.moves`, check that `six>=1.16.0` is in `requirements.txt` and rebuild the image.
* Use Minikube image loading if the cluster cannot pull from a registry.
