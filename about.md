# Helios RTB Engine - Simplified Overview

> **Quick Start**: For complete setup instructions, see [COMPLETE_SETUP_GUIDE.md](COMPLETE_SETUP_GUIDE.md)

## What is Helios?

Helios is a **Real-Time Bidding (RTB) Engine** that simulates how online advertising works. When you visit a website with ad space, an auction happens in milliseconds to decide which ad you see. Helios demonstrates this entire process from start to finish.

### Real-World Context

This is how platforms like Google Ads, Facebook Ads, and The Trade Desk operate:
- 🚀 Processes happen in **under 100 milliseconds**
- 💰 Billions of dollars in ad spend flow through these systems
- 📊 User data drives targeting and pricing decisions
- ⚡ Millions of auctions happen every second

## How It Works (5-Step Flow)

1. **Bid Request Arrives** → Website sends request: "I have ad space for user-001"
2. **User Enrichment** → System looks up interests from Redis: "technology: 0.95, sports: 0.70"
3. **Bid Calculation** → Algorithm decides price: "High tech interest → bid $1.20"
4. **Auction** → Simulator checks threshold and determines winner
5. **Analytics** → Results stored in PostgreSQL, displayed on dashboard

## The Six Core Services

### 1. **Bid Request Handler** (Go)
**Port**: 8080 | **What it does**: Front door for all incoming requests

- Written in Go for raw speed (handles 10,000+ requests/second)
- Validates incoming JSON and publishes to Kafka
- Exposes `/bid` endpoint and `/healthz` health check
- Prometheus metrics on port 2112

**Why Go?** Excellent for high-concurrency network services.

### 2. **User Profile Service** (Node.js/TypeScript)
**Port**: 50051 (gRPC) | **What it does**: Provides user data instantly

- Stores user profiles in Redis (in-memory = ultra-fast)
- Uses gRPC for sub-5ms response times
- Data structure: `{"user_id": "user-001", "interests": {"technology": 0.95, "sports": 0.70}}`
- Seed script populates demo users on startup

**Why Node.js + gRPC?** Event-driven architecture + Protocol Buffers efficiency.

### 3. **Bidding Logic Service** (Python)
**Port**: 8001 | **What it does**: The brain - decides bid prices

**Process**:
1. Consumes from Kafka topic `bid_requests`
2. Calls User Profile Service via gRPC
3. Calculates bid using interest-based algorithm:
   - High interest (>0.9) → **$1.20**
   - Medium (0.7-0.9) → **$0.85**
   - Low (0.5-0.7) → **$0.60**
   - Fallback → **$0.35**
4. Publishes to `bid_responses` topic

**Why Python?** Rich libraries for data processing and easy-to-read bidding logic.

### 4. **Auction Simulator** (Node.js)
**Port**: 9001 | **What it does**: Simulates the ad exchange auction

**Logic**:
- Reads from `bid_responses` Kafka topic
- Checks minimum bid threshold ($0.30)
- Uses probability (default 70%) to determine winners
- Publishes results to `auction_outcomes` topic

**Why Node.js?** Fast async processing for real-time decisions.

### 5. **Analytics Service** (Django/Python)
**Port**: 8000 | **What it does**: Permanent storage and REST API

**Two Components**:
- **API Server**: Django REST Framework exposing `/api/outcomes/`
- **Consumer**: Background process reading from `auction_outcomes` Kafka topic

**API Endpoints**:
- `GET /api/outcomes/` - List all outcomes (with pagination)
- `GET /api/outcomes/{id}/` - Get specific outcome
- `GET /api/outcomes/stats/` - Win rate, revenue, averages
- `GET /api/outcomes/winners/` - Only winning bids
- `GET /api/outcomes/daily-stats/` - Aggregated by date

**Database**: PostgreSQL with `outcomes_auctionoutcome` table

**Why Django?** Robust ORM, built-in admin panel, excellent REST framework.

### 6. **Advertiser Dashboard** (Next.js/React)
**Port**: 3000 | **What it does**: Visual interface for results

**Features**:
- Real-time metrics cards (total bids, wins, revenue)
- Win rate percentage with visual indicators
- Charts showing bid price distribution
- Filters and search capabilities
- Server-side rendering for performance

**Why Next.js?** Modern React framework with SSR, routing, and API routes built-in.

## Infrastructure Components

### Apache Kafka (Port 9092)
**Message bus connecting all services**

**Topics**:
- `bid_requests` - Raw incoming requests (3 partitions)
- `bid_responses` - Calculated bids (3 partitions)
- `auction_outcomes` - Final results (3 partitions)

**Why Kafka?** Decouples services, provides message durability, enables independent scaling.

### Redis (Port 6379)
**In-memory cache for user profiles**

- Sub-millisecond read times
- Simple key-value storage: `user-001` → `{...profile data...}`
- Seeded with demo data on startup

**Why Redis?** Speed is critical - bidding decisions happen in <100ms.

### PostgreSQL (Port 5432)
**Permanent analytics database**

- Stores all auction outcomes
- Supports complex queries and aggregations
- Named volume for data persistence

**Why PostgreSQL?** Reliable, feature-rich, excellent for analytics queries.

### Zookeeper (Port 2181)
**Kafka coordination service**

Required for Kafka cluster management and leader election.

## The Complete Data Journey

Let's trace a single request through the entire system:

```
┌──────────────────────────────────────────────────────────────┐
│ STEP 1: Request Arrives                                      │
└──────────────────────────────────────────────────────────────┘
POST http://localhost:8080/bid
{
  "request_id": "req-12345",
  "user_id": "user-001",
  "site": {"domain": "news.com"},
  "device": {"ip": "192.0.2.1"}
}
       ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 2: Published to Kafka (topic: bid_requests)             │
└──────────────────────────────────────────────────────────────┘
Bid Handler validates & publishes → returns HTTP 202 Accepted
       ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 3: Bidding Logic Consumes & Enriches                    │
└──────────────────────────────────────────────────────────────┘
Bidding Logic reads from Kafka
       ↓
gRPC call to User Profile: GetUserProfile(user_id="user-001")
       ↓
Response: {"interests": {"technology": 0.95, "sports": 0.70}}
       ↓
Calculate bid: technology score 0.95 > 0.9 → bid $1.20
       ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 4: Published to Kafka (topic: bid_responses)            │
└──────────────────────────────────────────────────────────────┘
{
  "bid_request_id": "req-12345",
  "bid_price": 1.20,
  "enriched": true,
  "winning_interest": "technology"
}
       ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 5: Auction Simulator Determines Winner                  │
└──────────────────────────────────────────────────────────────┘
Check: $1.20 > $0.30 threshold ✓
Random probability: 70% chance → WIN!
       ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 6: Published to Kafka (topic: auction_outcomes)         │
└──────────────────────────────────────────────────────────────┘
{
  "bid_request_id": "req-12345",
  "win_status": true,
  "win_price": 1.20,
  "auction_timestamp": "2025-10-30T12:00:00Z"
}
       ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 7: Analytics Consumer Persists to PostgreSQL            │
└──────────────────────────────────────────────────────────────┘
INSERT INTO outcomes_auctionoutcome (...)
       ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 8: Dashboard Queries Analytics API                      │
└──────────────────────────────────────────────────────────────┘
GET http://localhost:8000/api/outcomes/stats/
Response: {"total": 1, "wins": 1, "win_rate": 100%, "revenue": 1.20}
       ↓
Dashboard displays updated metrics to user
```

**Total time**: Typically 50-150ms end-to-end!

## Why This Architecture is Advanced

### 1. **Polyglot Programming**
Each service uses the best tool for its job:
- **Go**: Network performance (bid handler)
- **Python**: Data processing logic (bidding, analytics)
- **Node.js**: Async I/O (user profiles, auctions, UI)

### 2. **Event-Driven Design**
Services don't call each other directly (except gRPC for low latency). They communicate via Kafka messages, which:
- ✅ Decouples services (can deploy independently)
- ✅ Provides message durability (no data loss)
- ✅ Enables replay and debugging
- ✅ Allows independent scaling

### 3. **Database Per Service Pattern**
Each service owns its data:
- User Profile → Redis
- Analytics → PostgreSQL
- Communication → Kafka

### 4. **Rich Data Model**
Interest-based scoring enables sophisticated targeting:
```javascript
{
  "technology": 0.95,   // Very interested → bid high
  "sports": 0.70,       // Moderately interested → bid medium
  "cooking": 0.40       // Low interest → bid low or skip
}
```

### 5. **Production-Grade Observability**
- 📊 **Metrics**: Prometheus endpoints on every service
- 📝 **Logging**: Structured JSON logs to stdout
- ❤️ **Health Checks**: `/healthz` endpoints everywhere
- 🔍 **Tracing**: Request IDs flow through entire pipeline

## Running Locally

### Quick Start (3 commands)

```bash
# 1. Clone and navigate
git clone https://github.com/jigarbhoye04/devops.git
cd devops

# 2. Run setup script
./setup.sh

# 3. Verify
./test.sh
```

### What `setup.sh` Does

1. ✅ Builds 6 Docker images (Go, Python, Node.js services)
2. ✅ Starts infrastructure (Kafka, Redis, PostgreSQL)
3. ✅ Deploys all application services
4. ✅ Waits for health checks to pass
5. ✅ Creates 3 Kafka topics
6. ✅ Seeds Redis with demo user profiles
7. ✅ Runs Django migrations

**Time**: 3-5 minutes on first run, <1 minute for restarts.

### Access Points After Setup

| Service | URL | What You'll See |
|---------|-----|-----------------|
| **Dashboard** | http://localhost:3000 | Charts and metrics |
| **Analytics API** | http://localhost:8000/api/outcomes/ | JSON data |
| **Submit Bid** | `POST http://localhost:8080/bid` | 202 Accepted |
| **Metrics** | http://localhost:2112/metrics | Prometheus data |
| **Health** | http://localhost:8080/healthz | OK |

### Send Your First Bid

```bash
curl -X POST http://localhost:8080/bid \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "my-first-bid",
    "user_id": "user-001",
    "site": {"domain": "example.com"},
    "device": {"ip": "192.0.2.1"}
  }'
```

Then open http://localhost:3000 to see the result!

## What Makes This Production-Ready

### Security
- 🔒 All containers run as **non-root users**
- 🔐 Environment-based configuration (no hardcoded secrets)
- 🛡️ Health checks prevent unhealthy pods from serving traffic

### Scalability
- ⚖️ Kafka partitions enable horizontal scaling
- 📈 Stateless services can scale to N instances
- 🗄️ Database connection pooling

### Reliability
- 🔄 Automatic restarts via Docker/Kubernetes
- 💾 Persistent volumes for databases
- 📋 Structured logging for debugging

### Observability
- 📊 Prometheus metrics (counters, gauges, histograms)
- 📝 JSON logs with timestamps and context
- ❤️ Health checks at every layer

## Learning Resources

### Start Here
1. **[COMPLETE_SETUP_GUIDE.md](COMPLETE_SETUP_GUIDE.md)** - Comprehensive setup walkthrough
2. **[TEST_AND_VERIFY.md](TEST_AND_VERIFY.md)** - How to test everything
3. **[DEMO_MONITORING_GUIDE.md](DEMO_MONITORING_GUIDE.md)** - How to demo the system

### Go Deeper
4. **[Architecture](helios-rtb-engine/docs/architecture_and_flow.md)** - Technical design details
5. **[Phase Docs](helios-rtb-engine/docs/phases/)** - Development progression
6. **[ADRs](Docs/adr.md)** - Architecture decisions explained

## Technology Stack Summary

| Layer | Technologies |
|-------|-------------|
| **Languages** | Go, Python, TypeScript/JavaScript |
| **Frameworks** | FastAPI, Django, Express.js, Next.js |
| **Messaging** | Apache Kafka + Zookeeper |
| **Databases** | PostgreSQL, Redis |
| **Communication** | REST HTTP, gRPC (Protocol Buffers) |
| **Containerization** | Docker multi-stage builds |
| **Orchestration** | Docker Compose, Kubernetes |
| **Monitoring** | Prometheus metrics, JSON logging |

## Real-World Skills Demonstrated

This project showcases skills directly applicable to industry:

✅ **Microservices Architecture** - Service decomposition, API design  
✅ **Event-Driven Systems** - Kafka streaming, async processing  
✅ **Polyglot Development** - Multiple languages, picking the right tool  
✅ **Database Patterns** - Cache-aside (Redis), CQRS concepts  
✅ **RPC Frameworks** - gRPC for low-latency communication  
✅ **Container Orchestration** - Docker, Kubernetes, health checks  
✅ **Observability** - Metrics, logging, monitoring  
✅ **DevOps** - Automated setup, testing, deployment  

---

**Next Steps**: Follow [COMPLETE_SETUP_GUIDE.md](COMPLETE_SETUP_GUIDE.md) to get started! 🚀