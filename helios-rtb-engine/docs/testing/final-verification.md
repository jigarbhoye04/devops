# Final Verification Plan - Phase 4: Observability & User Interface

This document provides comprehensive instructions for testing the complete Helios RTB Engine system with all Phase 4 components deployed (Advertiser Dashboard, API Gateway, and Monitoring Stack).

## Prerequisites

- Kubernetes cluster running (Minikube, Kind, or cloud provider)
- `kubectl` configured to access the cluster
- Docker installed and configured
- All Phase 1-3 components successfully deployed and verified
- Helm (optional, for alternative deployment methods)

## Architecture Overview

After Phase 4 deployment, the complete system architecture includes:

```
┌─────────────────────────────────────────────────────────────────┐
│                       API Gateway (Traefik)                      │
│  Routes: /bid → Bid Handler                                      │
│          /api/outcomes → Analytics API                           │
│          /grafana → Grafana                                      │
│          /prometheus → Prometheus                                │
│          / → Advertiser Dashboard                                │
└─────────────────────────────────────────────────────────────────┘
                                  ↓
        ┌─────────────────────────┼─────────────────────────┐
        ↓                         ↓                         ↓
┌───────────────┐      ┌──────────────────┐      ┌─────────────────┐
│ Bid Request   │      │ Analytics API    │      │ Advertiser      │
│ Handler       │      │ (Django REST)    │      │ Dashboard       │
│ (Go + Metrics)│      │                  │      │ (Next.js)       │
└───────────────┘      └──────────────────┘      └─────────────────┘
        ↓                         ↓
    Kafka Topics              PostgreSQL
        ↓
┌───────────────┐
│ Bidding Logic │
│ Service       │
│ (Python +     │
│  Metrics)     │
└───────────────┘
        ↓
┌───────────────────────────────────────────┐
│         Prometheus + Grafana              │
│  - Scrapes metrics from services          │
│  - Visualizes system health & performance │
└───────────────────────────────────────────┘
```

## Step 1: Build and Push Docker Images

### 1.1 Build Advertiser Dashboard Image

```bash
cd services/advertiser-dashboard
docker build -t helios/advertiser-dashboard:phase4 .
cd ../..
```

### 1.2 Rebuild Services with Metrics

**Bid Request Handler:**
```bash
cd services/bid-request-handler
docker build -t helios/bid-request-handler:phase4 .
cd ../..
```

**Bidding Logic Service:**
```bash
cd services/bidding-logic-service
docker build -t helios/bidding-logic-service:phase4 .
cd ../..
```

### 1.3 Load Images into Minikube (if using Minikube)

```bash
minikube image load helios/advertiser-dashboard:phase4
minikube image load helios/bid-request-handler:phase4
minikube image load helios/bidding-logic-service:phase4
```

## Step 2: Deploy Gateway and Monitoring Infrastructure

### 2.1 Install Traefik CRDs (if not already installed)

```bash
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.0/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
```

### 2.2 Deploy Gateway Components

```bash
# Deploy RBAC for Traefik
kubectl apply -f kubernetes/gateway/rbac.yaml

# Deploy Traefik Gateway
kubectl apply -f kubernetes/gateway/deployment.yaml
kubectl apply -f kubernetes/gateway/service.yaml

# Deploy IngressRoute
kubectl apply -f kubernetes/gateway/ingressroute.yaml
```

### 2.3 Verify Gateway Deployment

```bash
kubectl get pods -n helios -l component=gateway
kubectl get svc -n helios gateway
kubectl describe ingressroute helios-gateway -n helios
```

Expected output:
- Gateway pod should be running
- Service should have NodePort assignments (30080 for HTTP, 30443 for HTTPS)

### 2.4 Deploy Prometheus

```bash
kubectl apply -f kubernetes/infra/prometheus-grafana/prometheus.yaml
```

### 2.5 Verify Prometheus

```bash
kubectl get pods -n helios -l component=prometheus
kubectl get svc -n helios prometheus

# Check Prometheus logs
kubectl logs -n helios -l component=prometheus --tail=50
```

### 2.6 Deploy Grafana

```bash
# Deploy Grafana dashboard ConfigMap
kubectl apply -f kubernetes/infra/prometheus-grafana/dashboards.yaml

# Deploy Grafana
kubectl apply -f kubernetes/infra/prometheus-grafana/grafana.yaml
```

### 2.7 Verify Grafana

```bash
kubectl get pods -n helios -l component=grafana
kubectl get svc -n helios grafana

# Check Grafana logs
kubectl logs -n helios -l component=grafana --tail=50
```

## Step 3: Deploy Advertiser Dashboard

### 3.1 Deploy Dashboard Components

```bash
kubectl apply -f kubernetes/services/06-advertiser-dashboard/configmap.yaml
kubectl apply -f kubernetes/services/06-advertiser-dashboard/deployment.yaml
kubectl apply -f kubernetes/services/06-advertiser-dashboard/service.yaml
```

### 3.2 Verify Dashboard Deployment

```bash
kubectl get pods -n helios -l component=advertiser-dashboard
kubectl get svc -n helios advertiser-dashboard-service

# Check dashboard logs
kubectl logs -n helios -l component=advertiser-dashboard --tail=50
```

## Step 4: Update Existing Services with Metrics

### 4.1 Update Bid Request Handler

```bash
kubectl set image deployment/bid-request-handler-deployment \
  bid-request-handler=helios/bid-request-handler:phase4 -n helios

# Wait for rollout
kubectl rollout status deployment/bid-request-handler-deployment -n helios
```

### 4.2 Update Bidding Logic Service

```bash
kubectl set image deployment/bidding-logic-service-deployment \
  bidding-logic-service=helios/bidding-logic-service:phase4 -n helios

# Wait for rollout
kubectl rollout status deployment/bidding-logic-service-deployment -n helios
```

### 4.3 Verify Metrics Endpoints

```bash
# Port-forward to check bid-request-handler metrics
kubectl port-forward -n helios deployment/bid-request-handler-deployment 2112:2112

# In another terminal, check metrics
curl http://localhost:2112/metrics | grep bid_requests_total

# Stop port-forward (Ctrl+C) and check bidding-logic-service
kubectl port-forward -n helios deployment/bidding-logic-service-deployment 8001:8001

# Check metrics
curl http://localhost:8001/metrics | grep bid_requests_processed_total
```

## Step 5: Access the System

### 5.1 Get Gateway URL

**For Minikube:**
```bash
minikube service gateway -n helios --url
```

**For other Kubernetes:**
```bash
kubectl get svc gateway -n helios
# Use the NodePort or LoadBalancer IP
```

Save this URL as `$GATEWAY_URL` for subsequent steps.

### 5.2 Access Grafana

Open your browser and navigate to:
```
http://$GATEWAY_URL/grafana
```

**Default credentials:**
- Username: `admin`
- Password: `admin`

1. Click on "Dashboards" (four squares icon)
2. Select "Helios RTB Engine - Overview"
3. You should see the pre-configured dashboard with panels for:
   - Bid Request Handler metrics
   - Bidding Logic Service metrics
   - User Profile enrichment
   - Circuit breaker state
   - Bid price distribution

### 5.3 Access Prometheus

Navigate to:
```
http://$GATEWAY_URL/prometheus
```

1. Go to Status → Targets
2. Verify all services are being scraped:
   - `kubernetes-pods` (should show bid-request-handler and bidding-logic-service)
   - `traefik`
   - `prometheus` (self-monitoring)

### 5.4 Access Advertiser Dashboard

Navigate to:
```
http://$GATEWAY_URL/
```

You should see:
- Header with "Helios RTB Dashboard" title
- Statistics cards showing:
  - Total Outcomes
  - Win Rate
  - Total Revenue
  - Avg Bid Price
- Charts showing:
  - Win Rate Over Time
  - Wins vs Losses
  - Daily Revenue
- Table of recent auction outcomes

## Step 6: Generate Load and Observe Metrics

### 6.1 Create Load Generation Script

Create a file `scripts/generate_load.sh`:

```bash
#!/bin/bash

GATEWAY_URL=${1:-http://localhost:30080}
NUM_REQUESTS=${2:-100}

echo "Generating $NUM_REQUESTS bid requests to $GATEWAY_URL"

for i in $(seq 1 $NUM_REQUESTS); do
  USER_ID="user-$(( RANDOM % 100 + 1 ))"
  REQUEST_ID="req-$(uuidgen)"
  
  PAYLOAD=$(cat <<EOF
{
  "request_id": "$REQUEST_ID",
  "user_id": "$USER_ID",
  "site_domain": "example.com",
  "device_type": "mobile",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

  curl -s -X POST "$GATEWAY_URL/bid" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null

  if [ $((i % 10)) -eq 0 ]; then
    echo "Sent $i requests..."
  fi
  
  # Small delay to avoid overwhelming the system
  sleep 0.1
done

echo "Load generation complete!"
```

Make it executable:
```bash
chmod +x scripts/generate_load.sh
```

### 6.2 Run Load Test

```bash
# Get gateway URL (Minikube example)
GATEWAY_URL=$(minikube service gateway -n helios --url | head -n 1)

# Generate 1000 bid requests
./scripts/generate_load.sh $GATEWAY_URL 1000
```

### 6.3 Observe Metrics in Grafana

Open Grafana dashboard and observe:

1. **Bid Request Handler panels:**
   - Request Rate should increase
   - Processing duration should show p50, p95, p99 latencies
   - Active Requests gauge should fluctuate

2. **Bidding Logic Service panels:**
   - Bid Processing Rate should show activity
   - Bid Generation Duration should be measured
   - User Profile Enrichment attempts visible

3. **Distribution panels:**
   - Bid Price Distribution pie chart fills up
   - Circuit Breaker State shows "Closed" (green)

4. **Error metrics:**
   - Kafka Publish Errors should remain near 0

### 6.4 Observe Data in Advertiser Dashboard

Refresh the Advertiser Dashboard (`http://$GATEWAY_URL/`):

1. Statistics cards should update:
   - Total Outcomes increases
   - Win Rate percentage updates
   - Total Revenue accumulates

2. Charts should populate:
   - Win Rate Over Time line chart shows trend
   - Wins vs Losses bar chart shows distribution
   - Daily Revenue chart shows accumulation

3. Table shows recent outcomes:
   - New rows appear at the top
   - Win/Loss status badges visible
   - Bid prices and timestamps displayed

4. Auto-refresh occurs every 30 seconds

## Step 7: Verify Data Flow End-to-End

### 7.1 Send a Single Test Request

```bash
curl -X POST "$GATEWAY_URL/bid" \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "test-request-123",
    "user_id": "user-42",
    "site_domain": "example.com"
  }'
```

Expected response: `202 Accepted`

### 7.2 Track Request Through System

**1. Check bid-request-handler logs:**
```bash
kubectl logs -n helios -l component=bid-request-handler --tail=20 | grep "test-request-123"
```

Should show: "Published bid request to Kafka"

**2. Check bidding-logic-service logs:**
```bash
kubectl logs -n helios -l component=bidding-logic-service --tail=30 | grep "test-request-123"
```

Should show:
- "Bid request received"
- "Processing bid request"
- "Bid response generated"
- "Bid response published"

**3. Check auction-simulator logs:**
```bash
kubectl logs -n helios -l component=auction-simulator --tail=30 | grep "test-request-123"
```

Should show:
- "Processing bid response"
- "Auction outcome determined"

**4. Check analytics-consumer logs:**
```bash
kubectl logs -n helios -l role=consumer --tail=30 | grep "test-request-123"
```

Should show: "Auction outcome saved"

**5. Query analytics API:**
```bash
curl "$GATEWAY_URL/api/outcomes/?bid_id=test-request-123" | jq
```

Should return the auction outcome JSON.

**6. Check Prometheus metrics:**

Port-forward to Prometheus:
```bash
kubectl port-forward -n helios svc/prometheus 9090:9090
```

Open `http://localhost:9090` and query:
```promql
bid_requests_total{status="success"}
```

Should show incremented counter.

**7. Verify in Advertiser Dashboard:**

Refresh the dashboard and look for the test request in the outcomes table.

## Step 8: Stress Test and Monitor

### 8.1 High-Volume Load Test

```bash
# Generate 10,000 requests over ~15 minutes
./scripts/generate_load.sh $GATEWAY_URL 10000
```

### 8.2 Monitor System Health

**In Grafana:**

1. Set time range to "Last 15 minutes"
2. Watch for:
   - Request rate peaks and valleys
   - Latency percentiles staying within acceptable ranges
   - No error rate spikes
   - Circuit breaker remaining closed

**In Prometheus:**

Query for error rates:
```promql
rate(kafka_publish_errors_total[5m])
rate(bid_requests_total{status="kafka_error"}[5m])
```

Both should be near 0.

**Check pod health:**
```bash
kubectl get pods -n helios
```

All pods should show "Running" status with healthy restart counts.

### 8.3 Verify Auto-Scaling (if configured)

```bash
kubectl get hpa -n helios
kubectl top pods -n helios
```

## Step 9: Test Dashboard Functionality

### 9.1 Test Pagination

1. Open Advertiser Dashboard
2. Click "Next" button at bottom of outcomes table
3. Verify page 2 loads with different outcomes
4. Click "Previous" to return to page 1

### 9.2 Test Auto-Refresh

1. Note the current data in statistics cards
2. In another terminal, send more bid requests
3. Wait 30 seconds (auto-refresh interval)
4. Observe statistics update automatically

### 9.3 Test Responsive Design

1. Resize browser window to mobile size
2. Verify layout adjusts properly
3. Charts remain readable
4. Table scrolls horizontally if needed

## Step 10: Performance Benchmarks

Document the following metrics after load testing:

### 10.1 System Throughput

```bash
# Query Prometheus for average request rate
kubectl port-forward -n helios svc/prometheus 9090:9090

# In Prometheus UI, query:
rate(bid_requests_total{status="success"}[5m])
```

**Expected:** > 100 requests/second

### 10.2 Latency Metrics

Query for percentiles:
```promql
histogram_quantile(0.95, sum(rate(request_processing_duration_seconds_bucket[5m])) by (le))
histogram_quantile(0.99, sum(rate(request_processing_duration_seconds_bucket[5m])) by (le))
```

**Expected:**
- p95 < 50ms
- p99 < 100ms

### 10.3 End-to-End Latency

Measure time from bid request to data appearing in Analytics API:

```bash
time (
  curl -X POST "$GATEWAY_URL/bid" -H "Content-Type: application/json" \
    -d '{"request_id":"'$(uuidgen)'","user_id":"user-test","site_domain":"test.com"}'
  sleep 5
  curl "$GATEWAY_URL/api/outcomes/?user_id=user-test"
)
```

**Expected:** < 5 seconds

### 10.4 Resource Usage

```bash
kubectl top pods -n helios
```

Monitor:
- CPU usage per pod
- Memory usage per pod

**Expected:**
- No pod exceeding resource limits
- No OOMKilled restarts

## Step 11: Failure Recovery Testing

### 11.1 Test Service Resilience

**Kill a pod and verify recovery:**
```bash
# Delete a bid-request-handler pod
kubectl delete pod -n helios -l component=bid-request-handler | head -n 1

# Verify new pod starts
kubectl get pods -n helios -l component=bid-request-handler -w

# Send requests to verify system still works
curl -X POST "$GATEWAY_URL/bid" -H "Content-Type: application/json" \
  -d '{"request_id":"'$(uuidgen)'","user_id":"user-test"}'
```

### 11.2 Test Circuit Breaker

**Simulate user-profile-service failure:**
```bash
# Scale down user-profile-service
kubectl scale deployment/user-profile-deployment -n helios --replicas=0

# Send requests
for i in {1..10}; do
  curl -X POST "$GATEWAY_URL/bid" -H "Content-Type: application/json" \
    -d '{"request_id":"'$(uuidgen)'","user_id":"user-test"}'
  sleep 1
done

# Check circuit breaker state in Grafana
# Should transition from Closed (0) to Open (1)
```

**Verify in Grafana:**
- Circuit Breaker State panel shows "Open" (red)
- User Profile Enrichment shows "Circuit Open" label increasing

**Restore service:**
```bash
kubectl scale deployment/user-profile-deployment -n helios --replicas=2
```

**Verify recovery:**
- Circuit breaker returns to "Closed" after reset timeout
- Enrichment success rate recovers

## Step 12: Data Validation

### 12.1 Verify Data Accuracy

Query analytics API for statistics:
```bash
curl "$GATEWAY_URL/api/outcomes/stats/" | jq
```

Expected fields:
```json
{
  "total_outcomes": 10000,
  "total_wins": 7000,
  "total_losses": 3000,
  "win_rate": 70.0,
  "total_revenue": 5600.00,
  "average_win_price": 0.80,
  "average_bid_price": 0.75,
  "enriched_count": 8500
}
```

### 12.2 Cross-Check with Prometheus

Compare Analytics API stats with Prometheus metrics:

```promql
# Total processed bids
sum(increase(bid_requests_processed_total[1h]))

# Should match Analytics API total_outcomes
```

## Troubleshooting Guide

### Issue: Dashboard shows "Failed to load data"

**Solution:**
1. Check analytics-service is running:
   ```bash
   kubectl get pods -n helios -l component=analytics-service
   ```

2. Verify ConfigMap has correct API URL:
   ```bash
   kubectl get configmap advertiser-dashboard-config -n helios -o yaml
   ```

3. Check dashboard logs:
   ```bash
   kubectl logs -n helios -l component=advertiser-dashboard
   ```

### Issue: Grafana shows "No data"

**Solution:**
1. Verify Prometheus is scraping targets:
   - Open Prometheus UI at `$GATEWAY_URL/prometheus`
   - Go to Status → Targets
   - Ensure all targets show "UP"

2. Check metrics are being exposed:
   ```bash
   kubectl port-forward -n helios deployment/bid-request-handler-deployment 2112:2112
   curl http://localhost:2112/metrics
   ```

3. Verify Grafana datasource:
   - Grafana → Configuration → Data Sources
   - Test connection to Prometheus

### Issue: Gateway returns 404

**Solution:**
1. Check IngressRoute status:
   ```bash
   kubectl describe ingressroute helios-gateway -n helios
   ```

2. Verify Traefik logs:
   ```bash
   kubectl logs -n helios -l component=gateway
   ```

3. Ensure services exist:
   ```bash
   kubectl get svc -n helios
   ```

### Issue: High latency in metrics

**Solution:**
1. Check resource usage:
   ```bash
   kubectl top pods -n helios
   ```

2. Scale up if needed:
   ```bash
   kubectl scale deployment/bid-request-handler-deployment -n helios --replicas=4
   ```

3. Verify Kafka is healthy:
   ```bash
   kubectl logs -n helios -l app=kafka
   ```

## Success Criteria

✅ **All components deployed and running:**
- Gateway (Traefik)
- Prometheus
- Grafana
- Advertiser Dashboard
- Updated services with metrics

✅ **Grafana dashboard accessible:**
- Shows real-time metrics
- All panels populated with data
- No error indicators

✅ **Advertiser Dashboard functional:**
- Displays statistics correctly
- Charts render properly
- Table shows recent outcomes
- Auto-refresh works
- Pagination works

✅ **Gateway routing correct:**
- `/bid` → Bid Request Handler
- `/api/outcomes` → Analytics API
- `/grafana` → Grafana
- `/prometheus` → Prometheus
- `/` → Advertiser Dashboard

✅ **Metrics collection working:**
- Prometheus scraping all services
- Custom metrics visible
- No scrape errors

✅ **Load test successful:**
- System handles 1000+ requests
- Latencies within acceptable range
- No errors or crashes
- Data flows end-to-end

✅ **Resilience verified:**
- Services recover from pod failures
- Circuit breaker functions correctly
- No data loss during failures

## Cleanup (Optional)

To tear down the Phase 4 components:

```bash
# Remove dashboard
kubectl delete -f kubernetes/services/06-advertiser-dashboard/

# Remove monitoring
kubectl delete -f kubernetes/infra/prometheus-grafana/

# Remove gateway
kubectl delete -f kubernetes/gateway/

# Revert services to previous versions if needed
kubectl set image deployment/bid-request-handler-deployment \
  bid-request-handler=helios/bid-request-handler:latest -n helios
kubectl set image deployment/bidding-logic-service-deployment \
  bidding-logic-service=helios/bidding-logic-service:latest -n helios
```

## Conclusion

Upon successful completion of this verification plan, you will have:

1. ✅ A fully functional web dashboard for viewing auction analytics
2. ✅ An API gateway routing traffic to all services
3. ✅ Complete observability with Prometheus and Grafana
4. ✅ Real-time metrics from all critical services
5. ✅ End-to-end data flow from bid requests to visual analytics
6. ✅ A production-ready RTB engine with monitoring and UI

**Next Steps:**
- Tune resource limits based on observed usage
- Set up alerting rules in Prometheus
- Add more Grafana dashboards for specific use cases
- Implement authentication for production deployment
- Set up persistent storage for Prometheus and Grafana data
