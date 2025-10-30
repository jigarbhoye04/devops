# Phase 3 End-to-End Verification Plan

## Overview

This document provides comprehensive instructions to test the complete data flow from bid request ingestion through to persisted analytics in the PostgreSQL database.

## Prerequisites

- Kubernetes cluster running (Minikube or equivalent)
- `kubectl` configured and connected to cluster
- All Phase 1 and Phase 2 components deployed
- Docker images built for Phase 3 services

## Architecture Overview

```
┌─────────────────────┐
│  Bid Request        │
│  Handler (Go)       │
└──────────┬──────────┘
           │ bid_requests (Kafka)
           ↓
┌─────────────────────┐      ┌─────────────────────┐
│  Bidding Logic      │─────→│  User Profile       │
│  Service (Python)   │←─────│  Service (Node.js)  │
└──────────┬──────────┘ gRPC └─────────────────────┘
           │ bid_responses (Kafka)
           ↓
┌─────────────────────┐
│  Auction Simulator  │
│  (Node.js)          │
└──────────┬──────────┘
           │ auction_outcomes (Kafka)
           ↓
┌─────────────────────┐      ┌─────────────────────┐
│  Analytics Consumer │─────→│  PostgreSQL         │
│  (Django)           │      │  Database           │
└─────────────────────┘      └─────────────────────┘
           ↓
┌─────────────────────┐
│  Analytics API      │
│  (Django REST)      │
└─────────────────────┘
```

## Step 1: Deploy PostgreSQL

### 1.1 Deploy PostgreSQL StatefulSet

```bash
# Apply PostgreSQL manifests
kubectl apply -f kubernetes/infra/postgres.yaml

# Verify deployment
kubectl get statefulset postgres -n helios
kubectl get pvc postgres-pvc -n helios
kubectl get service postgres -n helios
```

### 1.2 Verify PostgreSQL is Running

```bash
# Check pod status
kubectl get pods -n helios -l component=postgres

# Expected output:
# NAME         READY   STATUS    RESTARTS   AGE
# postgres-0   1/1     Running   0          30s

# Check logs
kubectl logs -n helios postgres-0

# Test database connection
kubectl exec -it postgres-0 -n helios -- psql -U helios -d helios_analytics -c '\l'
```

### 1.3 Verify Database and User

```bash
# List databases
kubectl exec -it postgres-0 -n helios -- psql -U helios -d postgres -c '\l'

# Expected: helios_analytics database exists

# Test credentials
kubectl exec -it postgres-0 -n helios -- \
  psql -U helios -d helios_analytics -c "SELECT version();"
```

## Step 2: Deploy Auction Service

### 2.1 Build Auction Service Docker Image

```bash
cd services/auction-simulator

# Build image
docker build -t helios/auction-simulator:phase3 .

# Verify image
docker images | grep auction-simulator
```

### 2.2 Deploy Auction Service

```bash
# Apply manifests
kubectl apply -f kubernetes/services/05-auction-simulator/deployment.yaml
kubectl apply -f kubernetes/services/05-auction-simulator/service.yaml

# Verify deployment
kubectl get deployment auction-simulator-deployment -n helios
kubectl get pods -n helios -l component=auction-simulator
kubectl get service auction-simulator -n helios
```

### 2.3 Check Auction Service Logs

```bash
# View logs
kubectl logs -n helios -l component=auction-simulator --tail=20

# Expected: Service started and connected to Kafka
# Look for: "Kafka consumer and producer connected"
```

## Step 3: Deploy Analytics Service

### 3.1 Build Analytics Service Docker Image

```bash
cd services/analytics-service

# Build image
docker build -t helios/analytics-service:phase3 .

# Verify image
docker images | grep analytics-service
```

### 3.2 Deploy Analytics Service

```bash
# Apply manifests
kubectl apply -f kubernetes/services/04-analytics-service/deployment.yaml
kubectl apply -f kubernetes/services/04-analytics-service/service.yaml

# Verify deployments
kubectl get deployment analytics-api-deployment -n helios
kubectl get deployment analytics-consumer-deployment -n helios
kubectl get pods -n helios -l component=analytics-service
kubectl get service analytics-service -n helios
```

### 3.3 Verify Database Migrations

```bash
# Check API pod logs for migrations
kubectl logs -n helios -l role=api --tail=50 | grep -i migrate

# Expected: "Running database migrations..." and "Operations to perform"

# Verify tables were created
kubectl exec -it postgres-0 -n helios -- \
  psql -U helios -d helios_analytics -c "\dt"

# Expected: outcomes_auctionoutcome table exists
```

### 3.4 Check Analytics Services

```bash
# Check API logs
kubectl logs -n helios -l role=api --tail=20

# Check consumer logs
kubectl logs -n helios -l role=consumer --tail=20 -f

# Expected consumer log: "Starting auction outcomes consumer"
```

## Step 4: Update Bidding Logic Service

### 4.1 Rebuild Bidding Logic Service

```bash
cd services/bidding-logic-service

# Build image with new bidding logic
docker build -t helios/bidding-logic-service:phase3 .
```

### 4.2 Update Deployment

```bash
# Update deployment to use new image
kubectl set image deployment/bidding-logic-service-deployment \
  bidding-logic-service=helios/bidding-logic-service:phase3 \
  -n helios

# Or reapply the deployment
kubectl apply -f kubernetes/services/03-bidding-logic-service/deployment.yaml

# Wait for rollout
kubectl rollout status deployment/bidding-logic-service-deployment -n helios
```

### 4.3 Verify Updated Service

```bash
# Check logs for new bidding logic
kubectl logs -n helios -l component=bidding-logic-service --tail=50

# Look for: "Bid price calculated from interest scores"
```

## Step 5: Send Test Bid Request

### 5.1 Prepare Test Data

Create a test bid request JSON file:

```bash
cat > test_bid_request.json <<EOF
{
  "request_id": "test-phase3-001",
  "user_id": "user-123",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "device_type": "mobile",
  "page_url": "https://example.com/tech-news",
  "site_domain": "example.com"
}
EOF
```

### 5.2 Send Request to Kafka

```bash
# Option 1: Using kafka-console-producer
kubectl run kafka-producer --rm -i --restart=Never \
  --image=confluentinc/cp-kafka:latest -n helios -- \
  kafka-console-producer \
  --broker-list kafka.helios.svc.cluster.local:9092 \
  --topic bid_requests < test_bid_request.json

# Option 2: Using curl to bid-request-handler (if exposed)
# Port forward first
kubectl port-forward -n helios svc/bid-request-handler 8080:8080 &

# Send request
curl -X POST http://localhost:8080/bid \
  -H "Content-Type: application/json" \
  -d @test_bid_request.json
```

### 5.3 Alternative: Send Multiple Test Requests

```bash
# Generate and send 10 test requests
for i in {1..10}; do
  echo "{\"request_id\":\"test-phase3-$(printf %03d $i)\",\"user_id\":\"user-$((i%3))\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"device_type\":\"mobile\",\"page_url\":\"https://example.com\"}" | \
  kubectl run kafka-producer-$i --rm -i --restart=Never \
    --image=confluentinc/cp-kafka:latest -n helios -- \
    kafka-console-producer \
    --broker-list kafka.helios.svc.cluster.local:9092 \
    --topic bid_requests
  sleep 2
done
```

## Step 6: Trace Request Flow Through Services

### 6.1 Monitor Bid Request Handler

```bash
# View logs
kubectl logs -n helios -l component=bid-request-handler --tail=20 -f

# Look for:
# - "Received bid request"
# - "Published to Kafka topic: bid_requests"
```

### 6.2 Monitor Bidding Logic Service

```bash
# View logs in new terminal
kubectl logs -n helios -l component=bidding-logic-service --tail=30 -f

# Look for:
# - "Bid request received"
# - "Processing bid request"
# - "Bid request enriched" (with user profile data)
# - "Bid price calculated from interest scores"
# - "Bid response generated"
# - "Bid response published"
```

### 6.3 Monitor Auction Simulator

```bash
# View logs in new terminal
kubectl logs -n helios -l component=auction-simulator --tail=30 -f

# Look for:
# - "Bid response received"
# - "Auction processed"
# - "Auction outcome published"
```

### 6.4 Monitor Analytics Consumer

```bash
# View logs in new terminal
kubectl logs -n helios -l role=consumer --tail=30 -f

# Look for:
# - "Message received"
# - "Auction outcome saved"
# - Success count incrementing
```

## Step 7: Verify Data in PostgreSQL

### 7.1 Check Database Records

```bash
# Count total outcomes
kubectl exec -it postgres-0 -n helios -- \
  psql -U helios -d helios_analytics -c \
  "SELECT COUNT(*) FROM outcomes_auctionoutcome;"

# View recent outcomes
kubectl exec -it postgres-0 -n helios -- \
  psql -U helios -d helios_analytics -c \
  "SELECT id, bid_id, user_id, win_status, win_price, enriched, timestamp 
   FROM outcomes_auctionoutcome 
   ORDER BY timestamp DESC 
   LIMIT 10;"

# Check win statistics
kubectl exec -it postgres-0 -n helios -- \
  psql -U helios -d helios_analytics -c \
  "SELECT 
     COUNT(*) as total_outcomes,
     SUM(CASE WHEN win_status THEN 1 ELSE 0 END) as wins,
     SUM(CASE WHEN NOT win_status THEN 1 ELSE 0 END) as losses,
     ROUND(AVG(CASE WHEN win_status THEN win_price ELSE 0 END)::numeric, 2) as avg_win_price
   FROM outcomes_auctionoutcome;"
```

### 7.2 Query Specific Test Request

```bash
# Find your test request
kubectl exec -it postgres-0 -n helios -- \
  psql -U helios -d helios_analytics -c \
  "SELECT * FROM outcomes_auctionoutcome 
   WHERE bid_id LIKE 'test-phase3%' 
   ORDER BY timestamp DESC;"
```

## Step 8: Test Analytics API

### 8.1 Port Forward Analytics Service

```bash
# Port forward API service
kubectl port-forward -n helios svc/analytics-service 8000:8000
```

### 8.2 Test API Endpoints

```bash
# In a new terminal, test endpoints:

# 1. List all outcomes
curl http://localhost:8000/api/outcomes/ | jq

# 2. Get statistics
curl http://localhost:8000/api/outcomes/stats/ | jq

# Expected response:
# {
#   "total_outcomes": 10,
#   "total_wins": 7,
#   "total_losses": 3,
#   "win_rate": 70.0,
#   "total_revenue": 5.60,
#   "average_win_price": 0.80,
#   "average_bid_price": 0.75,
#   "enriched_count": 10
# }

# 3. Get only winners
curl http://localhost:8000/api/outcomes/winners/ | jq

# 4. Filter by user
curl "http://localhost:8000/api/outcomes/?user_id=user-123" | jq

# 5. Get daily statistics
curl http://localhost:8000/api/outcomes/daily_stats/ | jq

# 6. Get specific outcome
OUTCOME_ID=$(curl -s http://localhost:8000/api/outcomes/ | jq -r '.results[0].id')
curl "http://localhost:8000/api/outcomes/${OUTCOME_ID}/" | jq
```

### 8.3 Verify API Response Data

Expected fields in outcome response:
- `id` - Database ID
- `bid_id` - Request ID
- `user_id` - User identifier
- `win_status` - Boolean (true/false)
- `win_price` - Decimal value
- `bid_price` - Original bid amount
- `enriched` - Whether profile was used
- `user_interests` - Array of interests
- `timestamp` - ISO 8601 datetime
- `created_at`, `updated_at` - Audit fields

## Step 9: End-to-End Validation

### 9.1 Complete Flow Test

```bash
# Run automated verification script
bash docs/testing/phase3_verify.sh
bash docs/testing/phase3.2_verify.sh

# Or run manual complete test:

# 1. Send test request
echo '{"request_id":"e2e-test-001","user_id":"user-999","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","device_type":"mobile","page_url":"https://example.com"}' | \
  kubectl run kafka-test --rm -i --restart=Never \
    --image=confluentinc/cp-kafka:latest -n helios -- \
    kafka-console-producer \
    --broker-list kafka.helios.svc.cluster.local:9092 \
    --topic bid_requests

# 2. Wait 5 seconds for processing
sleep 5

# 3. Check database
kubectl exec -it postgres-0 -n helios -- \
  psql -U helios -d helios_analytics -c \
  "SELECT * FROM outcomes_auctionoutcome WHERE bid_id = 'e2e-test-001';"

# 4. Check via API
curl "http://localhost:8000/api/outcomes/?user_id=user-999" | jq
```

### 9.2 Verify Complete Data Flow

Checklist:
- [ ] Bid request received by bid-request-handler
- [ ] Request published to `bid_requests` topic
- [ ] Bidding logic service consumed request
- [ ] User profile fetched via gRPC
- [ ] Bid price calculated using interest scores
- [ ] Bid response published to `bid_responses` topic
- [ ] Auction simulator consumed bid response
- [ ] Auction outcome determined
- [ ] Outcome published to `auction_outcomes` topic
- [ ] Analytics consumer received outcome
- [ ] Outcome saved to PostgreSQL
- [ ] Data retrievable via REST API

## Step 10: Performance and Load Testing

### 10.1 Send Burst of Requests

```bash
# Send 100 requests rapidly
for i in {1..100}; do
  echo "{\"request_id\":\"load-test-$(printf %04d $i)\",\"user_id\":\"user-$((RANDOM%10))\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"device_type\":\"mobile\",\"page_url\":\"https://example.com\"}" | \
  kubectl run kafka-load-$i --rm -i --restart=Never \
    --image=confluentinc/cp-kafka:latest -n helios -- \
    kafka-console-producer \
    --broker-list kafka.helios.svc.cluster.local:9092 \
    --topic bid_requests &
done

wait

# Wait for processing
sleep 30

# Check processing stats
kubectl exec -it postgres-0 -n helios -- \
  psql -U helios -d helios_analytics -c \
  "SELECT COUNT(*) FROM outcomes_auctionoutcome WHERE bid_id LIKE 'load-test%';"
```

### 10.2 Monitor Resource Usage

```bash
# Check pod resource usage
kubectl top pods -n helios

# Check service logs for errors
kubectl logs -n helios -l component=analytics-service --tail=100 | grep -i error
kubectl logs -n helios -l component=auction-simulator --tail=100 | grep -i error
kubectl logs -n helios -l component=bidding-logic-service --tail=100 | grep -i error
```

## Step 11: Access Django Admin Interface

### 11.1 Create Superuser

```bash
# Access API pod
kubectl exec -it deployment/analytics-api-deployment -n helios -- /bin/bash

# Create superuser
python manage.py createsuperuser
# Username: admin
# Email: admin@helios.local
# Password: [enter password]

# Exit pod
exit
```

### 11.2 Access Admin Interface

```bash
# Port forward (if not already done)
kubectl port-forward -n helios svc/analytics-service 8000:8000

# Open browser to:
# http://localhost:8000/admin/

# Login with credentials created above
# Navigate to "Auction Outcomes" to view data
```

## Troubleshooting

### Issue: No outcomes in database

**Check:**
```bash
# 1. Verify all services are running
kubectl get pods -n helios

# 2. Check Kafka topics exist
kubectl run kafka-topics --rm -i --restart=Never \
  --image=confluentinc/cp-kafka:latest -n helios -- \
  kafka-topics.sh --list --bootstrap-server kafka:9092

# 3. Check for messages in topics
kubectl run kafka-consumer --rm -i --restart=Never \
  --image=confluentinc/cp-kafka:latest -n helios -- \
  kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic auction_outcomes \
  --from-beginning --max-messages 5

# 4. Check consumer logs
kubectl logs -n helios -l role=consumer --tail=100
```

### Issue: Database connection errors

**Check:**
```bash
# Verify PostgreSQL is running
kubectl get pods -n helios -l component=postgres

# Test connection from analytics pod
kubectl exec -it deployment/analytics-api-deployment -n helios -- \
  python manage.py dbshell

# Check environment variables
kubectl get deployment analytics-api-deployment -n helios \
  -o jsonpath='{.spec.template.spec.containers[0].env}'
```

### Issue: API returning 500 errors

**Check:**
```bash
# View API logs
kubectl logs -n helios -l role=api --tail=100

# Run migrations manually
kubectl exec -it deployment/analytics-api-deployment -n helios -- \
  python manage.py migrate

# Restart API
kubectl rollout restart deployment/analytics-api-deployment -n helios
```

## Success Criteria

✅ **All services deployed and running:**
- PostgreSQL StatefulSet
- Auction Simulator
- Analytics API (2 replicas)
- Analytics Consumer (1 replica)
- Updated Bidding Logic Service

✅ **Data flow working:**
- Bid requests processed
- User profiles enriched
- Bids calculated using interest scores
- Auctions simulated
- Outcomes persisted to database

✅ **API functional:**
- All endpoints responding
- Statistics calculated correctly
- Filtering working
- Pagination working

✅ **Database populated:**
- Outcomes table exists
- Records being inserted
- Queries returning data
- Indexes working


## References

- [Phase 3.1 Documentation](../phases/03-auction-service.md)
- [Phase 3.2 Documentation](../phases/03.2-analytics-service.md)
- [Analytics Service README](../../services/analytics-service/README.md)
- [Auction Simulator README](../../services/auction-simulator/README.md)
