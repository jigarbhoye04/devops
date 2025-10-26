# Analytics Service - Quick Start Guide

## 🚀 Quick Start

### Local Development

1. **Install Dependencies**
   ```bash
   cd services/analytics-service
   pip install -r requirements.txt
   ```

2. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your database and Kafka settings
   ```

3. **Initialize Database**
   ```bash
   # Run migrations (REQUIRED - creates all tables)
   python manage.py migrate
   
   # Create superuser (optional)
   python manage.py createsuperuser
   ```
   
   ⚠️ **Important**: If you get a "table does not exist" error when testing the API, you skipped the migrations step. Run `python manage.py migrate` first.

4. **Start Services**
   
   Terminal 1 - API Server:
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```
   
   Terminal 2 - Kafka Consumer:
   ```bash
   python manage.py process_outcomes
   ```

5. **Test API**
   ```bash
   # View all outcomes
   curl http://localhost:8000/api/outcomes/
   
   # Get statistics
   curl http://localhost:8000/api/outcomes/stats/

   # Get winning outcomes only
   curl http://localhost:8000/api/outcomes/?win_status=true
   
   # Access admin interface
   # Open browser: http://localhost:8000/admin/
   ```

### Docker Deployment

1. **Build Image**
   ```bash
   docker build -t helios/analytics-service:phase3 .
   ```
   
   ✅ **Verify build succeeded:**
   ```bash
   docker images | grep helios/analytics-service
   ```

2. **Verify Database & Kafka are running in Docker**
   ```bash
   # Check if postgres is running
   docker ps | grep postgres
   
   # Check if kafka is running
   docker ps | grep kafka
   ```

3. **Run API Container**
   ```bash
   docker run -p 8000:8000 \
     --network devops_app-network \
     -e DB_HOST=postgres \
     -e DB_NAME=helios_db \
     -e DB_USER=admin \
     -e DB_PASSWORD=admin \
     -e KAFKA_BROKERS=kafka:29092 \
     -e KAFKA_TOPIC_AUCTION_OUTCOMES=auction_outcomes \
     -e KAFKA_CONSUMER_GROUP=analytics-service-group \
     helios/analytics-service:phase3 api
   ```
   
   ✅ **Verify API is running:**
   ```bash
   curl http://localhost:8000/api/outcomes/
   ```

4. **Run Consumer Container** (in separate terminal)
   ```bash
   docker run \
     --network devops_app-network \
     -e DB_HOST=postgres \
     -e DB_NAME=helios_db \
     -e DB_USER=admin \
     -e DB_PASSWORD=admin \
     -e KAFKA_BROKERS=kafka:29092 \
     -e KAFKA_TOPIC_AUCTION_OUTCOMES=auction_outcomes \
     -e KAFKA_CONSUMER_GROUP=analytics-service-group \
     helios/analytics-service:phase3 consumer
   ```
   
   ✅ **Verify consumer is processing:**
   ```bash
   docker logs <consumer-container-id>
   ```

5. **Test API from Docker**
   ```bash
   # View all outcomes
   curl http://localhost:8000/api/outcomes/
   
   # Get statistics
   curl http://localhost:8000/api/outcomes/stats/
   
   # Filter by win status
   curl http://localhost:8000/api/outcomes/?win_status=true
   ```

### Kubernetes Deployment

#### Quick Start
```bash
# One command deployment (from helios-rtb-engine directory):
cd ../../.. && ./scripts/deploy_analytics_k8s.sh

# Then port-forward:
kubectl port-forward -n helios svc/analytics-service 8000:8000

# Test in another terminal:
curl http://localhost:8000/api/outcomes/stats/
```

#### Prerequisites

1. **Enable Kubernetes in Docker Desktop**
   - Open Docker Desktop → Settings → Kubernetes
   - ✅ Check "Enable Kubernetes"
   - Wait for status indicator to show Kubernetes is running (bottom-left corner)
   - This may take 1-3 minutes on first setup
   
   **Verify Kubernetes is ready:**
   ```bash
   kubectl cluster-info
   # Should output cluster URLs, NOT "connection refused" error
   ```

2. **Dependencies Running**
   - PostgreSQL must be accessible from Kubernetes
   - Kafka must be accessible from Kubernetes
   - Both are configured to use in-cluster DNS names:
     - `postgres.helios.svc.cluster.local:5432`
     - `kafka.helios.svc.cluster.local:29092`

#### Step-by-Step Deployment

**Option A: Automated Deployment (Recommended)**

```bash
cd helios-rtb-engine
./scripts/deploy_analytics_k8s.sh

# Wait for output showing all pods ready
```

**Option B: Manual Deployment**

1. **Create namespace**
   ```bash
   kubectl create namespace helios
   ```

2. **Deploy analytics service**
   ```bash
   kubectl apply -f kubernetes/services/04-analytics-service/
   ```

3. **Verify deployment**
   ```bash
   # Check deployments
   kubectl get deployments -n helios

   # Check pods (wait for Running status)
   kubectl get pods -n helios -l component=analytics-service
   ```

#### Testing the Deployment

1. **Port forward the API service**
   ```bash
   kubectl port-forward -n helios svc/analytics-service 8000:8000
   ```

2. **In another terminal, test the API**
   ```bash
   # List outcomes (should be empty initially)
   curl http://localhost:8000/api/outcomes/
   
   # Get statistics
   curl http://localhost:8000/api/outcomes/stats/
   
   # Test filtering
   curl "http://localhost:8000/api/outcomes/?win_status=true"
   ```

3. **View pod logs**
   ```bash
   # API pod logs
   kubectl logs -n helios -l role=api -f --tail=50

   # Consumer pod logs
   kubectl logs -n helios -l role=consumer -f --tail=50
   ```

#### Pod Breakdown

**API Deployment (2 replicas)**
- Handles REST API requests on port 8000
- Endpoint: `/api/outcomes/`, `/api/outcomes/stats/`
- Resource limits: 512Mi memory, 500m CPU

**Consumer Deployment (1 replica)**
- Reads from Kafka topic `auction_outcomes`
- Processes and stores messages in PostgreSQL
- Runs continuously (no timeout)

#### Monitoring & Debugging

```bash
# Watch pod status in real-time
kubectl get pods -n helios -w

# View all resources in namespace
kubectl get all -n helios

# Describe a specific pod for issues
kubectl describe pod -n helios <pod-name>

# View pod events
kubectl get events -n helios --sort-by='.lastTimestamp'

# Check pod environment variables
kubectl exec -n helios <pod-name> -- env | grep DB_

# Get pod details
kubectl get pods -n helios -o wide

# Check pod resource usage
kubectl top pods -n helios
```

#### Troubleshooting

**Problem: Pods stuck in Pending state**
```bash
# Check events
kubectl get events -n helios --sort-by='.lastTimestamp'

# Most likely: Docker image not available
# Solution: Build the Docker image first
docker build -t helios/analytics-service:phase3 .
```

**Problem: CrashLoopBackOff**
```bash
# View logs to see error
kubectl logs -n helios <pod-name>

# Check environment configuration
kubectl describe deployment -n helios analytics-api-deployment

# Verify secrets created properly
kubectl get secrets -n helios
kubectl describe secret -n helios analytics-service-secrets
```

**Problem: Connection refused errors in logs**
```bash
# Verify PostgreSQL is accessible
kubectl run -it --rm debug --image=alpine --restart=Never -- \
  nc -zv postgres.helios.svc.cluster.local 5432

# Verify Kafka is accessible
kubectl run -it --rm debug --image=alpine --restart=Never -- \
  nc -zv kafka.helios.svc.cluster.local 29092
```

**Problem: API returns 502 Bad Gateway**
```bash
# Check pod status
kubectl get pods -n helios -l role=api

# Check API pod logs
kubectl logs -n helios -l role=api -f

# Verify service is exposing endpoints correctly
kubectl get svc -n helios analytics-service -o yaml
```

#### Cleanup

```bash
# Delete analytics service deployment
kubectl delete -f kubernetes/services/04-analytics-service/

# Delete namespace (removes all resources in it)
kubectl delete namespace helios

# Stop Kubernetes in Docker Desktop (optional)
# Settings → Kubernetes → Uncheck "Enable Kubernetes"
```

#### Common Tasks

```bash
# Scale up API replicas to 3
kubectl scale deployment -n helios analytics-api-deployment --replicas=3

# Rolling restart of pods
kubectl rollout restart deployment -n helios analytics-api-deployment

# View resource usage
kubectl top pods -n helios

# Port-forward consumer logs
kubectl logs -n helios -l role=consumer -f --tail=100

# Execute command in a running pod
kubectl exec -n helios <pod-name> -- django-admin shell

# Copy files from pod
kubectl cp helios/<pod-name>:/path/to/file ./local-file

# Port-forward multiple ports
kubectl port-forward -n helios svc/analytics-service 8000:8000 &
```

## 📊 API Endpoints

### Core Endpoints
- `GET /api/outcomes/` - List all outcomes (paginated)
- `GET /api/outcomes/{id}/` - Get specific outcome
- `GET /api/outcomes/stats/` - Get statistics
- `GET /api/outcomes/winners/` - Get winning outcomes
- `GET /api/outcomes/daily_stats/` - Daily aggregations

### Query Parameters
- `user_id` - Filter by user
- `site_domain` - Filter by domain  
- `win_status` - Filter by win/loss (true/false)
- `min_price`, `max_price` - Price range
- `ordering` - Sort by field (e.g., `-timestamp`)
- `page`, `page_size` - Pagination

## 🔍 Management Commands

```bash
# Run Kafka consumer
python manage.py process_outcomes

# Process limited messages
python manage.py process_outcomes --max-messages 100

# Database migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Django shell
python manage.py shell

# Run tests
python manage.py test
```

## 🧪 Testing

```bash
# Test database models
python test_models.py

# Test API endpoints
curl http://localhost:8000/api/outcomes/
curl http://localhost:8000/api/outcomes/stats/
curl "http://localhost:8000/api/outcomes/?win_status=true"

# Access admin interface
# http://localhost:8000/admin/
```

## 📝 Environment Variables

### Required
- `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`
- `KAFKA_BROKERS`
- `KAFKA_TOPIC_AUCTION_OUTCOMES`

### Optional
- `DJANGO_SECRET_KEY` (required for production)
- `DEBUG` (default: False)
- `ALLOWED_HOSTS` (default: *)
- `KAFKA_CONSUMER_GROUP` (default: analytics-service-group)
- `LOG_LEVEL` (default: INFO)

## 🐛 Troubleshooting

### "relation outcomes_auctionoutcome does not exist"
This means migrations haven't been run. Fix it:
```bash
python manage.py migrate
```

### Database Connection Issues
```bash
# Test connection
python manage.py dbshell

# Run migrations
python manage.py migrate
```

### Consumer Not Processing
```bash
# Check Kafka topic
kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic auction_outcomes --from-beginning

# Restart consumer
# Ctrl+C and restart: python manage.py process_outcomes
```

### API Errors
```bash
# Check logs
tail -f /var/log/analytics-service.log

# Or in Kubernetes
kubectl logs -n helios -l role=api --tail=100
```

## 📚 Documentation

- [Full README](README.md)
- [Phase 3.2 Documentation](../../docs/phases/03.2-analytics-service.md)
- [Verification Script](../../docs/testing/phase3.2_verify.sh)

## ✅ Verification

Run the verification script:
```bash
bash docs/testing/phase3.2_verify.sh
```

## 🎯 Success Criteria

- [x] Django application running
- [x] Database migrations applied
- [x] API responding at /api/outcomes/
- [x] Kafka consumer processing messages
- [x] Auction outcomes being persisted
- [x] Statistics endpoint working
- [x] Admin interface accessible

## 🔗 Related Services

- Auction Simulator → Produces to `auction_outcomes` topic
- PostgreSQL → Stores persistent data
- Kafka → Message broker

## 📞 Support

For issues or questions, check:
1. Service logs
2. Phase documentation
3. README.md
4. Kubernetes deployment manifests
