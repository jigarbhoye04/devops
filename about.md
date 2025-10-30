# Helios RTB Engine - System Overview

## What is Helios?

Helios is a **Real-Time Bidding (RTB) Engine** that simulates how online ads are bought and sold in milliseconds. When you visit a website with ad space, an auction happens instantly to determine which ad you see. Helios demonstrates this entire process.

## How It Works (Simple Flow)

1. **A website needs to show an ad** → sends a "bid request"
2. **System enriches the request** → looks up user interests from a profile database
3. **System calculates a bid** → decides how much to pay based on user interests
4. **Auction happens** → determines if the bid wins
5. **Results are stored** → analytics track what happened
6. **Dashboard displays data** → advertisers can see their performance

## The Seven Main Components

### 1. **Bid Request Handler** (Go)
- **What it does**: The front door for all incoming ad requests
- **Technology**: Written in Go for speed
- **Job**: Receives requests and immediately passes them to Kafka (message queue)
- **Why Go**: Can handle thousands of requests per second

### 2. **User Profile Service** (Node.js/TypeScript)
- **What it does**: Provides information about users
- **Technology**: Node.js with gRPC for ultra-fast communication
- **Storage**: Uses Redis (in-memory database) for instant access
- **Data**: Stores user interests with scores (e.g., "technology: 0.95", "sports: 0.70")

### 3. **Bidding Logic Service** (Python)
- **What it does**: The brain - decides how much to bid
- **Technology**: Python with sophisticated scoring algorithm
- **Process**: 
  - Reads requests from Kafka
  - Calls User Profile Service to get interests
  - Calculates bid price based on interest scores:
    - High interest (>0.9) → bids $1.20
    - Medium interest (0.7-0.9) → bids $0.85
    - Low interest (0.5-0.7) → bids $0.60
    - Default → bids $0.35
  - Sends bid to Kafka

### 4. **Auction Simulator** (Node.js)
- **What it does**: Simulates the auction to pick winners
- **Technology**: Node.js for quick processing
- **Logic**: 
  - Checks if bid meets minimum threshold ($0.30)
  - Uses probability (70% by default) to determine winner
  - Publishes results to Kafka

### 5. **Analytics Service** (Django/Python)
- **What it does**: Stores and analyzes all auction results
- **Technology**: Django REST Framework with PostgreSQL database
- **Features**:
  - Saves every auction outcome permanently
  - Provides API endpoints to query data
  - Calculates statistics (win rates, revenue, etc.)
  - Supports filtering by user, price range, win status

### 6. **Advertiser Dashboard** (Next.js/React)
- **What it does**: Visual interface to see results
- **Technology**: Next.js with React and charts
- **Displays**:
  - Total outcomes, wins, losses
  - Win rate percentage
  - Revenue and average prices
  - Charts showing trends over time

### 7. **Infrastructure Components**
- **Kafka**: Message bus that connects all services
- **Redis**: Fast cache for user profiles
- **PostgreSQL**: Permanent storage for analytics
- **Prometheus**: Collects performance metrics
- **Docker**: Packages everything to run together

## The Data Flow Journey

```
[Website] 
    ↓ 
[Bid Request Handler] → publishes to Kafka topic "bid_requests"
    ↓
[Bidding Logic] reads from Kafka
    ↓ calls via gRPC
[User Profile Service] returns interests
    ↓
[Bidding Logic] calculates price → publishes to "bid_responses"
    ↓
[Auction Simulator] decides winner → publishes to "auction_outcomes"
    ↓
[Analytics Service] saves to database
    ↓
[Dashboard] displays results
```

## Key Features

### Real-Time Processing
- Everything happens in milliseconds
- Uses Kafka for instant message delivery
- gRPC for ultra-fast service communication

### Data Enrichment
- Bids start basic, get enriched with user data
- Richer data → better targeting → higher bids

### Monitoring & Observability
- Every service exposes metrics
- Structured JSON logging throughout
- Health checks at every level

### Multiple Data Stores
- Redis for speed (user profiles)
- Kafka for reliability (message queue)
- PostgreSQL for permanence (analytics)

## Running Locally (Docker)

Everything runs on your Windows machine via WSL:

```bash
# Start everything
./setup.sh

# Verify it's working
./test.sh
```

**Access Points:**
- Bid endpoint: `http://localhost:8080/bid`
- Analytics API: `http://localhost:8000/api/outcomes/`
- Dashboard: `http://localhost:3000`
- Metrics: `http://localhost:2112/metrics` (bid handler), `http://localhost:8001/metrics` (bidding logic)

## What Makes This Advanced

1. **Polyglot Architecture**: Uses the best language for each job (Go for speed, Python for logic, Node.js for async)
2. **Event-Driven**: Services don't talk directly - they communicate via Kafka messages
3. **Circuit Breakers**: If User Profile Service fails, system keeps running with default bids
4. **Rich Data Model**: Interest scores enable sophisticated bidding strategies
5. **Full Observability**: Metrics, logs, and health checks throughout

## Real-World Relevance

This simulates how actual AdTech platforms work:
- **Google Ads**, **Facebook Ads**, **Amazon Advertising** all use similar architectures
- Sub-100ms response times are industry standard
- User profiling drives billions in ad revenue
- Event-driven design handles millions of requests

## Technology Stack Summary

| Component | Language | Database | Purpose |
|-----------|----------|----------|---------|
| Bid Handler | Go | Kafka | High-speed ingestion |
| User Profile | Node.js | Redis | Fast user lookups |
| Bidding Logic | Python | Kafka | Decision engine |
| Auction Simulator | Node.js | Kafka | Winner selection |
| Analytics | Python | PostgreSQL | Data persistence |
| Dashboard | Next.js | REST API | Visualization |

This architecture demonstrates modern microservices patterns, event-driven design, and real-time data processing - all skills directly applicable to building scalable systems.