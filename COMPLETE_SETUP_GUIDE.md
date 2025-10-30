# Helios RTB Engine: Complete Setup Guide from Scratch

This comprehensive guide walks you through setting up and running the entire Helios Real-Time Bidding (RTB) Engine project from scratch on a Windows machine using WSL2 and Docker.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Environment Setup](#2-environment-setup)
3. [Project Structure Overview](#3-project-structure-overview)
4. [Infrastructure Setup](#4-infrastructure-setup)
5. [Running the Project with Docker Compose](#5-running-the-project-with-docker-compose)
6. [Verification and Testing](#6-verification-and-testing)
7. [Monitoring and Observability](#7-monitoring-and-observability)
8. [Kubernetes Deployment (Advanced)](#8-kubernetes-deployment-advanced)
9. [Troubleshooting](#9-troubleshooting)
10. [Development Workflow](#10-development-workflow)

---

## 1. Prerequisites

### 1.1 System Requirements

- **Operating System**: Windows 10/11 with WSL2 enabled
- **RAM**: Minimum 8GB (16GB recommended)
- **Disk Space**: At least 10GB free
- **CPU**: Multi-core processor (4+ cores recommended)

### 1.2 Required Software

#### Step 1: Install WSL2

Open PowerShell as Administrator and run:

```powershell
wsl --install
```

This installs Ubuntu by default. Restart your computer when prompted.

After restart, verify WSL installation:

```powershell
wsl --list --verbose
```

You should see Ubuntu with version 2.

#### Step 2: Install Docker Desktop

1. Download Docker Desktop from: https://www.docker.com/products/docker-desktop
2. Install Docker Desktop (version 4.30 or later)
3. During installation, ensure "Use WSL 2 based engine" is selected
4. After installation, open Docker Desktop
5. Go to **Settings** → **Resources** → **WSL Integration**
6. Enable integration with your Ubuntu distribution

Verify Docker is working from WSL:

```bash
wsl
docker --version
docker compose version
```

#### Step 3: Install Git (if not already installed)

In WSL:

```bash
sudo apt update
sudo apt install -y git curl jq
```

### 1.3 Verify Prerequisites

Run these commands in WSL to ensure everything is ready:

```bash
# Check Docker
docker info --format '{{.ServerVersion}}'

# Check Docker Compose
docker compose version

# Check system resources
free -h
df -h
```

---

## 2. Environment Setup

### 2.1 Clone the Repository

Open WSL terminal:

```bash
# Navigate to Windows documents folder (accessible from WSL)
cd /mnt/c/Users/Jigar/Documents/GitHub

# If directory doesn't exist
mkdir -p /mnt/c/Users/Jigar/Documents/GitHub

# Clone the repository
git clone https://github.com/jigarbhoye04/devops.git
cd devops
```

### 2.2 Verify Project Structure

```bash
ls -la
```

You should see:
- `README.md`
- `SETUP.md`
- `setup.sh`
- `test.sh`
- `helios-rtb-engine/` directory
- `postman/` directory

### 2.3 Make Scripts Executable

```bash
chmod +x setup.sh
chmod +x test.sh
chmod +x pre_postman_check.sh
```

---

## 3. Project Structure Overview

The Helios RTB Engine is organized as a monorepo with the following structure:

### 3.1 Core Services

| Service | Language | Port | Purpose |
|---------|----------|------|---------|
| **Bid Request Handler** | Go | 8080 | HTTP ingestion endpoint for bid requests |
| **User Profile Service** | Node.js/TypeScript | 50051 | gRPC service for user data |
| **Bidding Logic Service** | Python | 8001 | Bid decision engine with user enrichment |
| **Auction Simulator** | Node.js | 9001 | Simulates ad exchange auction |
| **Analytics Service** | Python/Django | 8000 | Data persistence and REST API |
| **Advertiser Dashboard** | Next.js | 3000 | Web UI for advertisers |

### 3.2 Infrastructure Components

| Component | Port | Purpose |
|-----------|------|---------|
| **PostgreSQL** | 5432 | Primary database for analytics |
| **Redis** | 6379 | User profile caching |
| **Kafka** | 9092 | Asynchronous message bus |
| **Zookeeper** | 2181 | Kafka coordination |

### 3.3 Directory Layout

```
devops/
├── helios-rtb-engine/
│   ├── docker-compose.full.yml    # Complete Docker Compose configuration
│   ├── services/                   # All microservices source code
│   │   ├── bid-request-handler/   # Go service
│   │   ├── user-profile-service/  # Node.js gRPC service
│   │   ├── bidding-logic-service/ # Python consumer
│   │   ├── auction-simulator/     # Node.js auction engine
│   │   ├── analytics-service/     # Django API & consumer
│   │   └── advertiser-dashboard/  # Next.js frontend
│   ├── proto/                      # gRPC protocol definitions
│   ├── scripts/                    # Utility scripts
│   ├── kubernetes/                 # K8s manifests (optional)
│   └── docs/                       # Documentation
├── postman/                        # API testing collection
├── setup.sh                        # Automated setup script
├── test.sh                         # Verification script
└── README.md                       # Project overview
```

---

## 4. Infrastructure Setup

### 4.1 Understanding the Architecture

The Helios RTB Engine follows an event-driven architecture:

```
[HTTP Request] → [Bid Handler] → [Kafka: bid_requests] → [Bidding Logic]
                                                               ↓
                                                    [gRPC: User Profile]
                                                               ↓
                                  [Kafka: bid_responses] ← [Bidding Logic]
                                           ↓
                                  [Auction Simulator]
                                           ↓
                                  [Kafka: auction_outcomes]
                                           ↓
                                  [Analytics Service] → [PostgreSQL]
                                           ↓
                                  [REST API] → [Dashboard]
```

### 4.2 Configuration Overview

All services are configured via environment variables defined in `docker-compose.full.yml`. Key configurations:

**Database Configuration:**
```yaml
POSTGRES_DB: helios_analytics
POSTGRES_USER: helios
POSTGRES_PASSWORD: admin
```

**Kafka Configuration:**
```yaml
KAFKA_BROKERS: kafka:29092
KAFKA_TOPIC_BID_REQUESTS: bid_requests
KAFKA_TOPIC_BID_RESPONSES: bid_responses
KAFKA_TOPIC_AUCTION_OUTCOMES: auction_outcomes
```

**Service Endpoints:**
```yaml
USER_PROFILE_SVC_ADDR: user-profile-service:50051
ANALYTICS_API_URL: http://analytics-service-api:8000
```

---

## 5. Running the Project with Docker Compose

### 5.1 Automated Setup (Recommended)

The simplest way to get started:

```bash
cd /mnt/c/Users/Jigar/Documents/GitHub/devops
./setup.sh
```

This script will:
1. ✅ Build all Docker images
2. ✅ Start all containers in the correct order
3. ✅ Wait for health checks to pass
4. ✅ Create Kafka topics
5. ✅ Seed Redis with sample user profiles
6. ✅ Run database migrations

**Expected output:**
```
[setup] Building Docker images
[setup] Starting containers
[setup] Waiting for core infrastructure
[setup] Container helios-postgres is ready
[setup] Container helios-redis is ready
[setup] Container helios-kafka is ready
[setup] Waiting for application services
[setup] Bootstrapping Kafka topics
[setup] Seeding Redis with demo user profiles
[setup] Setup complete

---------------------------------------------------------------------
Helios RTB Engine services are online.

HTTP entrypoint:       http://localhost:8080/bid
Analytics API:         http://localhost:8000/api/outcomes/
Advertiser dashboard:  http://localhost:3000
Kafka bootstrap:       localhost:9092
---------------------------------------------------------------------
```

### 5.2 Setup Script Options

```bash
# Reset everything (clean start)
./setup.sh --reset

# Skip image rebuild (faster restarts)
./setup.sh --skip-build

# View help
./setup.sh --help
```

### 5.3 Manual Setup (Step-by-Step)

If you want to understand each step:

#### Step 1: Build Images

```bash
cd /mnt/c/Users/Jigar/Documents/GitHub/devops
docker compose -f helios-rtb-engine/docker-compose.full.yml build
```

#### Step 2: Start Infrastructure

```bash
# Start databases first
docker compose -f helios-rtb-engine/docker-compose.full.yml up -d postgres redis zookeeper kafka

# Wait for them to be healthy (30-60 seconds)
docker compose -f helios-rtb-engine/docker-compose.full.yml ps
```

#### Step 3: Start Application Services

```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml up -d
```

#### Step 4: Create Kafka Topics

```bash
# Create bid_requests topic
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-topics --bootstrap-server kafka:29092 \
  --create --topic bid_requests --partitions 3 --replication-factor 1

# Create bid_responses topic
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-topics --bootstrap-server kafka:29092 \
  --create --topic bid_responses --partitions 3 --replication-factor 1

# Create auction_outcomes topic
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-topics --bootstrap-server kafka:29092 \
  --create --topic auction_outcomes --partitions 3 --replication-factor 1
```

#### Step 5: Seed User Profiles

```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec user-profile-service \
  node dist/seed_redis.js
```

### 5.4 Verify All Services Are Running

```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml ps
```

**Expected output:** All services should show "Up" status with "(healthy)" for services with health checks.

```
NAME                          STATUS
helios-analytics-api          Up (healthy)
helios-analytics-consumer     Up
helios-auction-simulator      Up
helios-bid-handler            Up (healthy)
helios-bidding-logic          Up
helios-dashboard              Up (healthy)
helios-kafka                  Up (healthy)
helios-postgres               Up (healthy)
helios-redis                  Up (healthy)
helios-user-profile           Up (healthy)
helios-zookeeper              Up
```

---

## 6. Verification and Testing

### 6.1 Quick Health Check

Run the pre-flight check script:

```bash
./pre_postman_check.sh
```

This verifies all endpoints are responding.

### 6.2 Automated End-to-End Test

Run the comprehensive test suite:

```bash
./test.sh
```

This script:
- ✅ Checks container health
- ✅ Verifies Redis user profiles
- ✅ Sends sample bid requests
- ✅ Inspects Kafka topics
- ✅ Queries analytics API
- ✅ Tests gRPC endpoints

### 6.3 Manual Testing Steps

#### Step 1: Verify Container Health

```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml ps
```

All services should be "Up" or "Up (healthy)".

#### Step 2: Check Redis User Profiles

```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec redis \
  redis-cli KEYS "user-*"
```

You should see keys like `user-001`, `user-002`, etc.

#### Step 3: Send a Test Bid Request

Create a test bid request:

```bash
cat <<'EOF' > /tmp/test-bid.json
{
  "request_id": "test-req-001",
  "user_id": "user-001",
  "site": {
    "domain": "example.com",
    "page": "https://example.com/home"
  },
  "device": {
    "user_agent": "Mozilla/5.0",
    "ip": "192.0.2.1"
  },
  "ad_slots": [
    {
      "id": "slot-1",
      "min_bid": 0.35,
      "format": ["300x250"]
    }
  ]
}
EOF

curl -i -X POST \
  -H "Content-Type: application/json" \
  --data @/tmp/test-bid.json \
  http://localhost:8080/bid
```

**Expected response:**
```
HTTP/1.1 202 Accepted
Content-Type: application/json

{"status":"accepted","request_id":"test-req-001"}
```

#### Step 4: Check Kafka Topics

**View bid requests:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic bid_requests \
    --from-beginning \
    --max-messages 1
```

**View bid responses:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic bid_responses \
    --from-beginning \
    --max-messages 1
```

**View auction outcomes:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic auction_outcomes \
    --from-beginning \
    --max-messages 1
```

#### Step 5: Query Analytics Database

```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec postgres \
  psql -U helios -d helios_analytics -c \
  "SELECT bid_id, user_id, win_status, win_price, created_at FROM outcomes_auctionoutcome ORDER BY created_at DESC LIMIT 5;"
```

#### Step 6: Test Analytics API

```bash
# List all outcomes
curl -s http://localhost:8000/api/outcomes/ | jq '.'

# Get statistics
curl -s http://localhost:8000/api/outcomes/stats/ | jq '.'

# Get winners only
curl -s http://localhost:8000/api/outcomes/winners/ | jq '.'
```

#### Step 7: Test User Profile gRPC Service

The test script includes gRPC testing, or you can use grpcurl:

```bash
# Install grpcurl in WSL
sudo apt install -y grpcurl

# Test GetUserProfile
grpcurl -plaintext -d '{"user_id": "user-001"}' \
  localhost:50051 \
  userprofile.UserProfileService/GetUserProfile
```

#### Step 8: Access Advertiser Dashboard

Open your Windows browser and navigate to:
```
http://localhost:3000
```

You should see the dashboard with metrics and visualizations.

### 6.4 Postman Collection Testing

#### Step 1: Import Collection

1. Open Postman
2. Click **Import**
3. Navigate to: `\postman\helios-rtb-smoke.postman_collection.json`
4. Click **Import**

#### Step 2: Configure gRPC Request

1. Open the gRPC request in the collection
2. Click **Select Proto File**
3. Navigate to: `\devops\helios-rtb-engine\proto\user_profile.proto`
4. Select the file

#### Step 3: Run Tests

Execute the collection folders in order:
1. **Health Checks** - Verify all services are responding
2. **Bid Submission** - Send various bid scenarios
3. **Analytics API** - Query analytics data
4. **Monitoring** - Check metrics endpoints
5. **gRPC** - Test user profile service

---

## 7. Monitoring and Observability

### 7.1 Service Logs

View logs for any service:

```bash
# Bid Request Handler
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f bid-request-handler

# Bidding Logic Service
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f bidding-logic-service

# Auction Simulator
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f auction-simulator

# Analytics API
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f analytics-service-api

# All services
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f
```

### 7.2 Prometheus Metrics

Services expose Prometheus metrics:

**Bid Request Handler Metrics:**
```bash
curl http://localhost:2112/metrics | grep bid_requests_total
```

**Bidding Logic Service Metrics:**
```bash
curl http://localhost:8001/metrics | grep bid_requests_processed
```

### 7.3 Database Monitoring

**Check PostgreSQL connections:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec postgres \
  psql -U helios -d helios_analytics -c \
  "SELECT count(*) FROM pg_stat_activity;"
```

**Check table sizes:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec postgres \
  psql -U helios -d helios_analytics -c \
  "SELECT relname, n_live_tup FROM pg_stat_user_tables;"
```

### 7.4 Redis Monitoring

```bash
# Check Redis info
docker compose -f helios-rtb-engine/docker-compose.full.yml exec redis \
  redis-cli INFO stats

# Check memory usage
docker compose -f helios-rtb-engine/docker-compose.full.yml exec redis \
  redis-cli INFO memory
```

### 7.5 Kafka Monitoring

**List all topics:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-topics --bootstrap-server kafka:29092 --list
```

**Describe a topic:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-topics --bootstrap-server kafka:29092 --describe --topic bid_requests
```

**Check consumer groups:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-consumer-groups --bootstrap-server kafka:29092 --list
```

---

## 8. Kubernetes Deployment (Advanced)

For production-like multi-node deployment:

### 8.1 Prerequisites

- Kubernetes cluster (minikube, k3s, or cloud provider)
- kubectl installed and configured
- Docker images pushed to a registry (or use local registry)

### 8.2 Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f helios-rtb-engine/kubernetes/00-namespace.yaml

# Deploy infrastructure (Kafka, PostgreSQL, Redis)
kubectl apply -f helios-rtb-engine/kubernetes/infra/

# Deploy services
kubectl apply -f helios-rtb-engine/kubernetes/services/

# Deploy gateway
kubectl apply -f helios-rtb-engine/kubernetes/gateway/
```

### 8.3 Verify Kubernetes Deployment

```bash
# Check pods
kubectl get pods -n helios

# Check services
kubectl get svc -n helios

# View logs
kubectl logs -n helios -l app=helios,component=bid-request-handler
```

---

## 9. Troubleshooting

### 9.1 Common Issues

#### Docker Engine Not Running

**Symptom:** `Cannot connect to the Docker daemon`

**Solution:**
1. Open Docker Desktop in Windows
2. Ensure the engine is running
3. Check WSL integration is enabled

#### Port Already in Use

**Symptom:** `Bind for 0.0.0.0:8080 failed: port is already allocated`

**Solution:**
```bash
# Find process using the port (in Windows PowerShell)
netstat -ano | findstr :8080

# Or stop the stack and start fresh
docker compose -f helios-rtb-engine/docker-compose.full.yml down
./setup.sh
```

#### Container Health Check Failing

**Symptom:** Container shows "unhealthy" status

**Solution:**
```bash
# View container logs
docker compose -f helios-rtb-engine/docker-compose.full.yml logs <service-name>

# Restart specific service
docker compose -f helios-rtb-engine/docker-compose.full.yml restart <service-name>

# Complete reset
docker compose -f helios-rtb-engine/docker-compose.full.yml down -v
./setup.sh --reset
```

#### Kafka Topics Not Created

**Symptom:** Consumer services can't find topics

**Solution:**
```bash
# Recreate topics manually
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-topics --bootstrap-server kafka:29092 --create --topic bid_requests --partitions 3 --replication-factor 1

docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-topics --bootstrap-server kafka:29092 --create --topic bid_responses --partitions 3 --replication-factor 1

docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-topics --bootstrap-server kafka:29092 --create --topic auction_outcomes --partitions 3 --replication-factor 1
```

#### Database Migration Issues

**Symptom:** Analytics API returns 500 errors

**Solution:**
```bash
# Run migrations manually
docker compose -f helios-rtb-engine/docker-compose.full.yml exec analytics-service-api \
  python manage.py migrate

# Check migration status
docker compose -f helios-rtb-engine/docker-compose.full.yml exec analytics-service-api \
  python manage.py showmigrations
```

#### Redis Not Seeded

**Symptom:** User enrichment fails

**Solution:**
```bash
# Seed Redis manually
docker compose -f helios-rtb-engine/docker-compose.full.yml exec user-profile-service \
  node dist/seed_redis.js

# Verify
docker compose -f helios-rtb-engine/docker-compose.full.yml exec redis \
  redis-cli KEYS "user-*"
```

### 9.2 Complete Reset

If all else fails, do a complete reset:

```bash
# Stop everything
docker compose -f helios-rtb-engine/docker-compose.full.yml down -v

# Remove all Helios images
docker images | grep helios | awk '{print $3}' | xargs docker rmi -f

# Clean Docker system
docker system prune -f

# Start fresh
./setup.sh --reset
```

### 9.3 Debugging Tips

**View all container statuses:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml ps -a
```

**Inspect a specific container:**
```bash
docker inspect <container-name>
```

**Execute commands in a running container:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec <service-name> /bin/sh
```

**Check resource usage:**
```bash
docker stats
```

---

## 10. Development Workflow

### 10.1 Making Code Changes

When you modify service code:

```bash
# Rebuild specific service
docker compose -f helios-rtb-engine/docker-compose.full.yml build <service-name>

# Restart the service
docker compose -f helios-rtb-engine/docker-compose.full.yml up -d <service-name>

# View logs
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f <service-name>
```

**Example - Modify Bidding Logic Service:**
```bash
# Edit code in helios-rtb-engine/services/bidding-logic-service/

# Rebuild
docker compose -f helios-rtb-engine/docker-compose.full.yml build bidding-logic-service

# Restart
docker compose -f helios-rtb-engine/docker-compose.full.yml up -d bidding-logic-service

# Watch logs
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f bidding-logic-service
```

### 10.2 Running Tests

Each service has its own tests:

```bash
# Analytics Service tests
docker compose -f helios-rtb-engine/docker-compose.full.yml exec analytics-service-api \
  python manage.py test

# Auction Simulator tests
docker compose -f helios-rtb-engine/docker-compose.full.yml exec auction-simulator \
  npm test
```

### 10.3 Code Quality

**Formatting:**
```bash
# From project root
npm run format
```

**Linting:**
```bash
npm run lint
```

### 10.4 Database Operations

**Create Django superuser:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec analytics-service-api \
  python manage.py createsuperuser
```

**Access Django admin:**
```
http://localhost:8000/admin
```

**Run Django shell:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec analytics-service-api \
  python manage.py shell
```

### 10.5 Generating Load for Testing

Use the demo data generator:

```bash
# Generate 50 bid requests with 0.2s delay between each
python3 helios-rtb-engine/scripts/populate_demo_data.py --count 50 --delay 0.2
```

Monitor the effect:
```bash
# Watch metrics increase
watch -n 1 'curl -s http://localhost:2112/metrics | grep bid_requests_total'

# Watch analytics grow
watch -n 1 'curl -s http://localhost:8000/api/outcomes/stats/ | jq .'
```

---

## 11. Next Steps

### 11.1 Learn More

- Read the architecture documentation: `helios-rtb-engine/docs/architecture_and_flow.md`
- Review phase-by-phase implementation: `helios-rtb-engine/docs/phases/`
- Check ADRs (Architecture Decision Records): `helios-rtb-engine/docs/adr/`

### 11.2 Extend the System

Ideas for enhancement:
- Add machine learning-based bid pricing
- Implement real-time dashboard updates with WebSockets
- Add Prometheus/Grafana for advanced monitoring
- Implement circuit breakers and retry logic
- Add authentication and authorization
- Scale services horizontally

### 11.3 Production Considerations

Before going to production:
- Change all default passwords
- Enable TLS/SSL everywhere
- Implement proper secret management
- Set up automated backups
- Configure monitoring and alerting
- Implement rate limiting
- Add comprehensive error handling
- Set up CI/CD pipelines

---

## 12. Quick Reference

### 12.1 Essential Commands

```bash
# Start everything
./setup.sh

# Stop everything
docker compose -f helios-rtb-engine/docker-compose.full.yml down

# Reset and start fresh
./setup.sh --reset

# Run tests
./test.sh

# View all logs
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f

# Check status
docker compose -f helios-rtb-engine/docker-compose.full.yml ps
```

### 12.2 Service URLs

| Service | URL |
|---------|-----|
| Bid Ingestion | http://localhost:8080/bid |
| Analytics API | http://localhost:8000/api/outcomes/ |
| Dashboard | http://localhost:3000 |
| Bid Handler Metrics | http://localhost:2112/metrics |
| Bidding Logic Metrics | http://localhost:8001/metrics |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |
| Kafka | localhost:9092 |

### 12.3 Default Credentials

- **PostgreSQL:** user=`helios`, password=`admin`, database=`helios_analytics`
- **Redis:** No authentication by default
- **Kafka:** No authentication by default

---

## Support and Contribution

For issues or questions:
1. Check the troubleshooting section
2. Review the documentation in `helios-rtb-engine/docs/`
3. Check container logs for specific errors
4. Consult the test scripts for working examples

Happy bidding! 🚀
