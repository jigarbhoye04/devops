# Analytics Service - Deployment Verification Guide

## ✅ Local Development Verification

### 1. Prerequisites Check

```bash
# Check Python version
python --version  # Should be 3.12+

# Check virtual environment
echo $VIRTUAL_ENV  # Should show venv path

# Check Django
python -c "import django; print(django.get_version())"

# Check database connection
python manage.py dbshell
# Should connect to helios_db with admin user
```

### 2. Database Setup Verification

```bash
# Run migrations
python manage.py migrate

# Check migrations applied
python manage.py migrate --plan

# Expected output:
# [X] auth.0001_initial
# [X] auth.0002_alter_permission_name_max_length
# ... (all migrations marked with [X])
```

### 3. API Server Verification

```bash
# Start API server
python manage.py runserver 0.0.0.0:8000

# In another terminal, test endpoints:
curl http://localhost:8000/api/outcomes/
# Expected: {"count": 0, "next": null, "previous": null, "results": []}

curl http://localhost:8000/api/outcomes/stats/
# Expected: {"total_outcomes": 0, "total_wins": 0, ...}

curl http://localhost:8000/admin/
# Expected: Django admin login page
```

### 4. Kafka Consumer Verification

```bash
# Start consumer
python manage.py process_outcomes

# Expected logs:
# {"timestamp": "...", "level": "INFO", "message": "Starting auction outcomes consumer"}
# {"timestamp": "...", "level": "INFO", "message": "Kafka consumer started"}

# Consumer should stay running, waiting for messages
```

### 5. Infrastructure Verification

```bash
# Check PostgreSQL running
docker ps | grep postgres
# Should show: postgres:15-alpine running on 5432

# Check Kafka running
docker ps | grep kafka
# Should show: confluentinc/cp-kafka:7.3.2 running

# Check Zookeeper running
docker ps | grep zookeeper
# Should show: confluentinc/cp-zookeeper:7.3.2 running

# Verify Kafka topic exists
docker exec devops-kafka-1 kafka-topics --list --bootstrap-server localhost:9092
# Should include: auction_outcomes
```

---

## 🐳 Docker Deployment Verification

### 1. Build Docker Image

```bash
cd helios-rtb-engine/services/analytics-service

# Build image
docker build -t helios/analytics-service:phase3 .

# Verify build succeeded
docker images | grep helios/analytics-service
# Expected output: helios/analytics-service   phase3   <image-id>   <size>
```

### 2. Run API Container

```bash
docker run -d \
  --name analytics-api \
  --network devops_app-network \
  -p 8000:8000 \
  -e DB_HOST=postgres \
  -e DB_NAME=helios_db \
  -e DB_USER=admin \
  -e DB_PASSWORD=admin \
  -e KAFKA_BROKERS=kafka:29092 \
  -e KAFKA_TOPIC_AUCTION_OUTCOMES=auction_outcomes \
  -e KAFKA_CONSUMER_GROUP=analytics-service-group \
  helios/analytics-service:phase3 api

# Check container is running
docker ps | grep analytics-api

# View logs
docker logs analytics-api
# Should see: "Starting API server" and migration output

# Test API
curl http://localhost:8000/api/outcomes/
# Expected: {"count": 0, ...}
```

### 3. Run Consumer Container

```bash
docker run -d \
  --name analytics-consumer \
  --network devops_app-network \
  -e DB_HOST=postgres \
  -e DB_NAME=helios_db \
  -e DB_USER=admin \
  -e DB_PASSWORD=admin \
  -e KAFKA_BROKERS=kafka:29092 \
  -e KAFKA_TOPIC_AUCTION_OUTCOMES=auction_outcomes \
  -e KAFKA_CONSUMER_GROUP=analytics-service-group \
  helios/analytics-service:phase3 consumer

# Check container is running
docker ps | grep analytics-consumer

# View logs
docker logs -f analytics-consumer
# Should see: "Starting Kafka consumer" and "Kafka consumer started"
```

### 4. Verify Docker Containers

```bash
# List all running containers
docker ps

# Check API health
curl http://localhost:8000/api/outcomes/health/ || curl http://localhost:8000/api/outcomes/

# Check consumer logs
docker logs analytics-consumer | tail -20

# Check API logs
docker logs analytics-api | tail -20
```

### 5. Test End-to-End

```bash
# Send test message to Kafka (in another terminal)
docker exec devops-kafka-1 kafka-console-producer \
  --broker-list localhost:9092 \
  --topic auction_outcomes <<EOF
{"bid_request_id": "test-1", "user_id": "user-123", "win_status": true, "win_price": 10.5, "bid_price": 8.0}
EOF

# Check consumer processed it
docker logs analytics-consumer | grep "Auction outcome saved"

# Query API
curl http://localhost:8000/api/outcomes/
# Should now show: {"count": 1, "next": null, ...}

# Check stats
curl http://localhost:8000/api/outcomes/stats/
# Should show: {"total_outcomes": 1, "total_wins": 1, ...}
```

---

## 🚀 Kubernetes Deployment Verification

### 1. Deploy to Kubernetes

```bash
# Navigate to kubernetes manifests
cd kubernetes/services/04-analytics-service/

# Apply manifests
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Check deployment
kubectl get deployments -n helios
# Expected: analytics-service with 1/1 replicas ready
```

### 2. Verify Pods

```bash
# Check pods
kubectl get pods -n helios -l component=analytics-service
# Expected: pods with names like analytics-service-xxx running

# View pod logs
kubectl logs -n helios -l component=analytics-service -f

# Describe pod for issues
kubectl describe pod -n helios <pod-name>
```

### 3. Port Forward and Test

```bash
# Port forward to local machine
kubectl port-forward -n helios svc/analytics-service 8000:8000 &

# Test API
curl http://localhost:8000/api/outcomes/

# Test statistics
curl http://localhost:8000/api/outcomes/stats/
```

---

## 📊 Common Verification Commands

### Check All Services Running

```bash
# Local development check
echo "=== Python Packages ==="
pip list | grep -i "django\|psycopg\|kafka"

echo "=== Docker Containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}"

echo "=== Database ==="
python manage.py dbshell
SELECT COUNT(*) FROM outcomes_auctionoutcome;
\q

echo "=== Kafka Topics ==="
docker exec devops-kafka-1 kafka-topics --list --bootstrap-server localhost:9092

echo "=== Consumer Group ==="
docker exec devops-kafka-1 kafka-consumer-groups --list --bootstrap-server localhost:9092
```

### Test Data Flow

```bash
# Terminal 1: Start API
python manage.py runserver 0.0.0.0:8000

# Terminal 2: Start Consumer
python manage.py process_outcomes

# Terminal 3: Send test message
docker exec devops-kafka-1 kafka-console-producer \
  --broker-list localhost:9092 \
  --topic auction_outcomes < test_message.json

# Terminal 4: Check data in API
curl http://localhost:8000/api/outcomes/
curl http://localhost:8000/api/outcomes/stats/

# Check database directly
python manage.py dbshell
SELECT * FROM outcomes_auctionoutcome;
```

---

## ⚠️ Troubleshooting

### Database Errors

```bash
# Error: "relation outcomes_auctionoutcome does not exist"
# Solution:
python manage.py migrate
python manage.py makemigrations outcomes  # If needed
python manage.py migrate

# Error: Connection refused to localhost:5432
# Solution:
docker ps | grep postgres
# If not running, start docker: docker-compose up -d
```

### Kafka Connection Errors

```bash
# Error: NoBrokersAvailable
# Solution:
docker ps | grep kafka
docker logs devops-kafka-1  # Check Kafka logs
# Verify KAFKA_BROKERS in .env: should be localhost:9092 (local) or kafka:29092 (docker)

# Error: Topic does not exist
# Solution:
docker exec devops-kafka-1 kafka-topics --list --bootstrap-server localhost:9092
# If auction_outcomes not present, create it or let Kafka auto-create
```

### Docker Build Failures

```bash
# Error: Dockerfile not found
# Solution: Run from analytics-service directory
cd helios-rtb-engine/services/analytics-service
docker build -t helios/analytics-service:phase3 .

# Error: Network not found
# Solution: Ensure docker-compose network exists
docker network ls | grep devops_app-network
docker-compose up -d  # To recreate network if needed

# Error: Port already in use
# Solution:
docker ps -a  # Find container using port
docker stop <container-id>
docker rm <container-id>
```

---

## ✅ Success Indicators

When everything is working:

- ✅ `docker ps` shows postgres, kafka, zookeeper, and analytics containers running
- ✅ `curl http://localhost:8000/api/outcomes/` returns JSON response
- ✅ Consumer logs show "Kafka consumer started"
- ✅ Database has `outcomes_auctionoutcome` table
- ✅ Sending messages to Kafka topic results in data being saved
- ✅ API stats endpoint shows updated counts

---

## 📝 Quick Reference

| Component | Local | Docker | Kubernetes |
|-----------|-------|--------|------------|
| Database | `python manage.py migrate` | Auto on startup | Auto on startup |
| API | `python manage.py runserver` | `docker run ... api` | `kubectl apply -f` |
| Consumer | `python manage.py process_outcomes` | `docker run ... consumer` | `kubectl apply -f` |
| Test API | `curl http://localhost:8000/api/` | `curl http://localhost:8000/api/` | `kubectl port-forward` |
