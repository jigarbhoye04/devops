<!-- ### Project Idea: Real-time, Context-Aware Ad Bidding Engine

This project simulates a core component of AdTech: a Real-Time Bidding (RTB) exchange. When a user visits a website, an ad auction happens in milliseconds. Your system will receive bid requests, enrich them with user data, decide which ad to show, and log the outcome. This is a high-throughput, low-latency problem.

**Why this is advanced:** This isn't a simple web app. It's a distributed data pipeline that must make complex decisions in under 100ms. It forces a focus on performance, caching, asynchronous processing, and stateful analytics.

**Core Services & Technology Stack:**

| Service | Programming Language | Database / Data Store | Responsibilities |
| :--- | :--- | :--- | :--- |
| **Bid Request Handler** | **Go** | (None - interfaces with Kafka) | A high-concurrency endpoint that receives incoming ad bid requests. It does initial validation and immediately publishes the request onto a Kafka topic for processing. Go is chosen here for its raw networking performance to handle massive request volumes. This is your "new language" service. |
| **User Profile Service** | **Node.js (TypeScript)** | **Redis** | A low-latency service that provides user data. Given a user ID from a bid request, it fetches a user profile (browsing history, interests) from a Redis cache to enable targeted advertising. It communicates via **gRPC** for maximum speed. |
| **Bidding Logic Service** | **Python (FastAPI)** | (None - in-memory logic) | Consumes bid requests from Kafka. It calls the User Profile Service (**gRPC**) to get context, then runs the core bidding logic (e.g., "for a user interested in 'hiking', bid $0.05 for this Nike ad"). It publishes its bid decision to another Kafka topic. |
| **Auction Service** | **Node.js (JavaScript)** | (None - real-time logic) | Consumes bids from multiple Bidding Logic instances, runs a quick "auction" (selects the highest bid), and determines the winner. The winning bid is sent back to the original requestor (simulated). |
| **Analytics & Reporting Service** | **Python (Django)** | **PostgreSQL / ClickHouse** | Asynchronously consumes auction result events from Kafka. It aggregates this data into a reporting database (like PostgreSQL or a specialized analytical DB like ClickHouse) and provides a **Next.js**-based dashboard for advertisers to see their campaign performance (impressions, spend, etc.). |

**Architectural Components & Communication:**

*   **Front-end:** A sophisticated **Next.js** dashboard for the **Analytics & Reporting Service**.
*   **Asynchronous Backbone:** **Kafka** is the core of the system, decoupling the high-speed ingestion from the enrichment, bidding, and analytics stages. This allows different parts of the system to scale independently.
*   **Low-Latency Synchronous Communication:** The critical path from the Bidding Logic to the User Profile Service uses **gRPC** for sub-millisecond data retrieval.
*   **API Gateway:** Manages and secures the entry point for the Bid Request Handler and the REST API for the Analytics dashboard.
*   **Polyglot Persistence:** You'll use Redis for its caching speed, and a powerful SQL or analytical database for complex reporting queries, perfectly demonstrating the "database per service" concept.
*   **Orchestration:** All services run in Docker containers managed by a Kubernetes cluster across your three laptops, simulating a distributed production environment.



--- -->

# Helios RTB Engine

<div align="center">

![Helios RTB Engine](https://img.shields.io/badge/Status-Production%20Ready-success)
![Docker](https://img.shields.io/badge/Docker-Compose-blue)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Ready-326CE5)
![License](https://img.shields.io/badge/License-MIT-green)

**A Production-Grade Real-Time Bidding Engine**

[Quick Start](#quick-start) • [Documentation](#documentation) • [Architecture](#architecture) • [Contributing](#contributing)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Features](#features)
- [Project Structure](#project-structure)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

**Helios** is a distributed Real-Time Bidding (RTB) Engine that simulates a Demand-Side Platform (DSP) in the AdTech ecosystem. The system processes ad placement opportunities in real-time, enriches them with user data, makes intelligent bidding decisions in under 100 milliseconds, and provides comprehensive analytics.

### Project Vision

This project demonstrates mastery of:
- **Polyglot Programming** - Go, Python, Node.js/TypeScript
- **Event-Driven Architecture** - Apache Kafka message streaming
- **Microservices Design** - Independent, scalable services
- **Database Per Service** - Redis, PostgreSQL, Kafka
- **Cloud-Native Deployment** - Docker, Kubernetes, multi-node orchestration
- **Production Observability** - Structured logging, metrics, health checks

### What is Real-Time Bidding?

When a user visits a website with ad space, an auction happens in milliseconds:

1. **Bid Request** - Ad exchange sends opportunity to multiple DSPs (our system)
2. **User Enrichment** - System looks up user interests and demographics
3. **Bid Calculation** - Algorithm decides bid price based on user profile
4. **Auction** - Exchange selects the highest bidder
5. **Win Notification** - Winner's ad is displayed; system logs the outcome

Helios simulates this entire pipeline end-to-end.

---

## Quick Start

### Prerequisites

- **Windows 10/11** with WSL2 enabled
- **Docker Desktop** (v4.30+) with WSL2 integration
- **8GB RAM** minimum (16GB recommended)
- **10GB** free disk space

### Installation (5 Minutes)

```bash
# 1. Open WSL terminal
wsl

# 2. Clone the repository
git clone https://github.com/jigarbhoye04/devops.git
cd devops

# 3. Make scripts executable
chmod +x setup.sh test.sh pre_postman_check.sh

# 4. Start everything
./setup.sh
```

The setup script will:
- Build all Docker images
- Start infrastructure (Kafka, Redis, PostgreSQL)
- Deploy all microservices
- Create Kafka topics
- Seed sample user data
- Run health checks

### Verify Installation

```bash
# Run comprehensive test suite
./test.sh

# Or quick health check
./pre_postman_check.sh
```

### Access Points

Once running, access the system:

| Service | URL | Description |
|---------|-----|-------------|
| **Dashboard** | http://localhost:3000 | Advertiser analytics UI |
| **Analytics API** | http://localhost:8000/api/outcomes/ | REST API for data |
| **Bid Ingestion** | http://localhost:8080/bid | Submit bid requests |
| **Metrics** | http://localhost:2112/metrics | Prometheus metrics |

### Send Your First Bid

```bash
curl -X POST http://localhost:8080/bid \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "demo-001",
    "user_id": "user-001",
    "site": {"domain": "example.com"},
    "device": {"ip": "192.0.2.1"}
  }'
```

Then check the dashboard at http://localhost:3000 to see results!

---

## Documentation

### Getting Started
- **[Complete Setup Guide](COMPLETE_SETUP_GUIDE.md)** - Comprehensive installation and configuration
- **[SETUP.md](SETUP.md)** - WSL/Docker setup specifics
- **[About Helios](about.md)** - Simple explanation of the system

### Testing & Verification
- **[TEST_AND_VERIFY.md](TEST_AND_VERIFY.md)** - End-to-end testing procedures
- **[Demo Guide](DEMO_MONITORING_GUIDE.md)** - How to demo the system

### Architecture
- **[Architecture Overview](helios-rtb-engine/docs/architecture_and_flow.md)** - System design and data flow
- **[Phase 1: Core Pipeline](helios-rtb-engine/docs/phases/01-core-pipeline.md)** - Asynchronous processing
- **[Phase 3: Auction Service](helios-rtb-engine/docs/phases/03-auction-service.md)** - Auction logic
- **[Phase 3.2: Analytics](helios-rtb-engine/docs/phases/03.2-analytics-service.md)** - Data persistence

### Development
- **[ADR](Docs/adr.md)** - Architecture Decision Records
- **[Execution Plan](Docs/exec_plan.md)** - Development workflow
- **[Development Prompts](Docs/dev_prompts.md)** - LLM-assisted development guide

---

## Architecture

### System Overview

The Helios RTB Engine is an event-driven pipeline built on Apache Kafka:

```
┌─────────────────────────────────────────────────────────────────┐
│                        HELIOS RTB ENGINE                         │
└─────────────────────────────────────────────────────────────────┘

[HTTP Request] 
      ↓
┌──────────────────┐
│ Bid Handler (Go) │ → Kafka: bid_requests
└──────────────────┘
      ↓
┌──────────────────────┐       ┌────────────────────────┐
│ Bidding Logic (Py)   │──────→│ User Profile (Node.js) │
│                      │←──────│ (gRPC)                 │
└──────────────────────┘       └────────────────────────┘
      ↓                               ↓
Kafka: bid_responses              [Redis Cache]
      ↓
┌─────────────────────┐
│ Auction (Node.js)   │ → Kafka: auction_outcomes
└─────────────────────┘
      ↓
┌─────────────────────┐       ┌──────────────┐
│ Analytics (Django)  │──────→│ PostgreSQL   │
└─────────────────────┘       └──────────────┘
      ↓
┌─────────────────────┐
│ Dashboard (Next.js) │ → [Browser UI]
└─────────────────────┘
```

### Core Services

| Service | Language | Port | Responsibilities |
|---------|----------|------|------------------|
| **Bid Request Handler** | Go | 8080, 2112 | HTTP ingestion, Kafka producer |
| **User Profile Service** | Node.js/TypeScript | 50051 | gRPC user data provider, Redis interface |
| **Bidding Logic Service** | Python | 8001 | Kafka consumer, bid calculation, gRPC client |
| **Auction Simulator** | Node.js | 9001 | Auction logic, winner determination |
| **Analytics Service** | Python/Django | 8000 | Data persistence, REST API, Kafka consumer |
| **Advertiser Dashboard** | Next.js | 3000 | Web UI, data visualization |

### Infrastructure Components

| Component | Port | Purpose |
|-----------|------|---------|
| **Apache Kafka** | 9092 | Asynchronous message bus (3 topics) |
| **Redis** | 6379 | User profile cache (sub-5ms lookups) |
| **PostgreSQL** | 5432 | Analytics database |
| **Zookeeper** | 2181 | Kafka coordination |

---

## Technology Stack

### Languages & Frameworks

- **Go** - High-performance HTTP server (Bid Request Handler)
- **Python** - FastAPI-based bidding logic, Django REST for analytics
- **Node.js/TypeScript** - gRPC services, auction simulator, Next.js dashboard
- **React** - Dashboard frontend with chart visualizations

### Databases & Messaging

- **Apache Kafka** - Event streaming platform
- **Redis** - In-memory data store for user profiles
- **PostgreSQL** - Relational database for analytics

### Infrastructure & DevOps

- **Docker** - Multi-stage containerization
- **Docker Compose** - Local orchestration
- **Kubernetes** - Production-grade deployment
- **Prometheus** - Metrics collection
- **gRPC** - High-performance RPC framework

---

## Features

### Real-Time Processing
- **Sub-100ms** bid request processing
- **Event-driven** architecture with Kafka
- **gRPC** for ultra-low latency service communication

### User Enrichment
- **Profile-based bidding** using Redis cache
- **Interest scoring** (technology, sports, travel, etc.)
- **Dynamic pricing** based on user engagement scores

### Analytics & Reporting
- **Real-time dashboard** with Next.js
- **Statistics API** - win rates, revenue, average prices
- **Advanced filtering** by user, price range, win status
- **Daily aggregations** and trend analysis

### Observability
- **Structured JSON logging** across all services
- **Prometheus metrics** endpoints
- **Health checks** for every component
- **Request tracing** through the entire pipeline

### Production-Ready
- **Multi-stage Docker builds** for minimal image sizes
- **Non-root containers** for security
- **Environment-based configuration** (12-factor app)
- **Kubernetes manifests** for multi-node deployment

---

## Project Structure

```
devops/
├── helios-rtb-engine/           # Main project directory
│   ├── docker-compose.full.yml  # Complete Docker Compose setup
│   │
│   ├── services/                # All microservices
│   │   ├── bid-request-handler/      # Go HTTP server
│   │   ├── user-profile-service/     # Node.js gRPC service
│   │   ├── bidding-logic-service/    # Python Kafka consumer
│   │   ├── auction-simulator/        # Node.js auction engine
│   │   ├── analytics-service/        # Django API + consumer
│   │   └── advertiser-dashboard/     # Next.js frontend
│   │
│   ├── kubernetes/              # K8s deployment manifests
│   │   ├── 00-namespace.yaml
│   │   ├── infra/              # Infrastructure (Kafka, Redis, Postgres)
│   │   ├── services/           # Application services
│   │   └── gateway/            # API gateway (Traefik)
│   │
│   ├── proto/                   # gRPC protocol definitions
│   │   └── user_profile.proto
│   │
│   ├── scripts/                 # Utility scripts
│   │   ├── populate_demo_data.py
│   │   └── generate_data.py
│   │
│   └── docs/                    # Documentation
│       ├── architecture_and_flow.md
│       ├── phases/             # Development phases
│       ├── adr/                # Architecture decisions
│       └── testing/            # Verification guides
│
├── postman/                     # API testing collection
│   └── helios-rtb-smoke.postman_collection.json
│
├── Docs/                        # Project-level docs
│   ├── adr.md                  # High-level ADRs
│   ├── exec_plan.md            # Execution strategy
│   └── dev_prompts.md          # Development guide
│
├── setup.sh                     # Automated setup script
├── test.sh                      # Verification script
├── pre_postman_check.sh        # Health check script
│
├── COMPLETE_SETUP_GUIDE.md     # Comprehensive setup guide
├── SETUP.md                    # WSL/Docker setup
├── TEST_AND_VERIFY.md          # Testing procedures
├── DEMO_MONITORING_GUIDE.md    # Demo walkthrough
├── about.md                    # System overview
└── README.md                   # This file
```

---

## Development

### Local Development Setup

```bash
# Clone the repository
git clone https://github.com/jigarbhoye04/devops.git
cd devops

# Start all services
./setup.sh

# Watch logs for a specific service
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f <service-name>
```

### Making Changes

When you modify a service:

```bash
# Rebuild the service
docker compose -f helios-rtb-engine/docker-compose.full.yml build <service-name>

# Restart the service
docker compose -f helios-rtb-engine/docker-compose.full.yml up -d <service-name>

# View logs
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f <service-name>
```

### Code Quality

```bash
# Format code
npm run format

# Lint code
npm run lint
```

### Service-Specific Commands

**Analytics Service (Django):**
```bash
# Run migrations
docker compose -f helios-rtb-engine/docker-compose.full.yml exec analytics-service-api \
  python manage.py migrate

# Create superuser
docker compose -f helios-rtb-engine/docker-compose.full.yml exec analytics-service-api \
  python manage.py createsuperuser

# Run tests
docker compose -f helios-rtb-engine/docker-compose.full.yml exec analytics-service-api \
  python manage.py test
```

**Auction Simulator (Node.js):**
```bash
# Run tests
docker compose -f helios-rtb-engine/docker-compose.full.yml exec auction-simulator \
  npm test
```

---

## Testing

### Automated Testing

```bash
# Complete end-to-end test suite
./test.sh

# Quick health checks
./pre_postman_check.sh
```

### Manual Testing

**1. Check all services are running:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml ps
```

**2. Send a test bid request:**
```bash
curl -X POST http://localhost:8080/bid \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "test-001",
    "user_id": "user-001",
    "site": {"domain": "test.com"},
    "device": {"ip": "192.0.2.1"}
  }'
```

**3. Query analytics API:**
```bash
# Get all outcomes
curl http://localhost:8000/api/outcomes/

# Get statistics
curl http://localhost:8000/api/outcomes/stats/

# Get only winners
curl http://localhost:8000/api/outcomes/winners/
```

**4. Inspect Kafka topics:**
```bash
# View bid requests
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-console-consumer --bootstrap-server kafka:29092 \
  --topic bid_requests --from-beginning --max-messages 1

# View auction outcomes
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-console-consumer --bootstrap-server kafka:29092 \
  --topic auction_outcomes --from-beginning --max-messages 1
```

### Postman Collection

Import `postman/helios-rtb-smoke.postman_collection.json` into Postman for a comprehensive test suite covering:
- Health checks
- Bid submission scenarios
- Analytics API queries
- gRPC user profile calls
- Metrics endpoints

### Load Testing

Generate sustained load:
```bash
python3 helios-rtb-engine/scripts/populate_demo_data.py --count 100 --delay 0.1
```

---

## Deployment

### Docker Compose (Local/Development)

```bash
# Start everything
./setup.sh

# Stop everything
docker compose -f helios-rtb-engine/docker-compose.full.yml down

# Complete reset (removes volumes)
docker compose -f helios-rtb-engine/docker-compose.full.yml down -v
./setup.sh --reset
```

### Kubernetes (Production)

```bash
# Create namespace
kubectl apply -f helios-rtb-engine/kubernetes/00-namespace.yaml

# Deploy infrastructure
kubectl apply -f helios-rtb-engine/kubernetes/infra/

# Deploy services
kubectl apply -f helios-rtb-engine/kubernetes/services/

# Deploy gateway
kubectl apply -f helios-rtb-engine/kubernetes/gateway/

# Check status
kubectl get pods -n helios
kubectl get svc -n helios
```

### Configuration

All services are configured via environment variables. Key settings in `docker-compose.full.yml`:

**Database:**
```yaml
POSTGRES_DB: helios_analytics
POSTGRES_USER: helios
POSTGRES_PASSWORD: admin  # Change in production!
```

**Kafka:**
```yaml
KAFKA_BROKERS: kafka:29092
KAFKA_TOPIC_BID_REQUESTS: bid_requests
KAFKA_TOPIC_BID_RESPONSES: bid_responses
KAFKA_TOPIC_AUCTION_OUTCOMES: auction_outcomes
```

**Services:**
```yaml
USER_PROFILE_SVC_ADDR: user-profile-service:50051
ANALYTICS_API_URL: http://analytics-service-api:8000
```

---

## Troubleshooting

### Common Issues

**Docker not running:**
```bash
# Verify Docker is accessible
docker info
```

**Port conflicts:**
```bash
# Stop the stack
docker compose -f helios-rtb-engine/docker-compose.full.yml down

# Or find what's using the port (Windows PowerShell)
netstat -ano | findstr :8080
```

**Container unhealthy:**
```bash
# View logs
docker compose -f helios-rtb-engine/docker-compose.full.yml logs <service-name>

# Restart service
docker compose -f helios-rtb-engine/docker-compose.full.yml restart <service-name>
```

**Complete reset:**
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml down -v
./setup.sh --reset
```

See [COMPLETE_SETUP_GUIDE.md](COMPLETE_SETUP_GUIDE.md#9-troubleshooting) for detailed troubleshooting.

---

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature/amazing-feature`
3. **Commit your changes:** `git commit -m 'Add amazing feature'`
4. **Push to branch:** `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Workflow

- Follow the coding standards in `.github/copilot-instructions.md`
- Write tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting PR

---

## Monitoring & Metrics

### Prometheus Metrics

Each service exposes metrics on dedicated ports:

```bash
# Bid Request Handler
curl http://localhost:2112/metrics | grep bid_requests_total

# Bidding Logic Service
curl http://localhost:8001/metrics | grep bid_requests_processed
```

### Service Logs

View structured JSON logs:

```bash
# All services
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f

# Specific service
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f bidding-logic-service
```

### Database Monitoring

```bash
# PostgreSQL queries
docker compose -f helios-rtb-engine/docker-compose.full.yml exec postgres \
  psql -U helios -d helios_analytics -c \
  "SELECT COUNT(*) FROM outcomes_auctionoutcome;"

# Redis keys
docker compose -f helios-rtb-engine/docker-compose.full.yml exec redis \
  redis-cli KEYS "user-*"
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Built with modern microservices architecture principles
- Inspired by real-world AdTech platforms (Google Ads, The Trade Desk)
- Demonstrates cloud-native best practices
- Educational project showcasing distributed systems design

---

## Support

For issues, questions, or contributions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review the [documentation](#-documentation)
3. Check container logs for errors
4. Open an issue on GitHub

---

<div align="center">

**Built with using Go, Python, Node.js, Kafka, Redis, and PostgreSQL**

[Back to top](#helios-rtb-engine)

</div>