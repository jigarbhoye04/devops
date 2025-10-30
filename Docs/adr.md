# Helios RTB Engine - Architecture Decision Records

> **Note**: For complete system architecture, see [helios-rtb-engine/docs/architecture_and_flow.md](../helios-rtb-engine/docs/architecture_and_flow.md)

## 1. Monorepo Directory Structure

For a project with multiple interconnected services, a **monorepo** (single repository containing all project code) provides significant benefits for dependency management, versioning, and integration testing.

### Current Structure

```
/devops/
├── helios-rtb-engine/          # Main project directory
│   ├── docker-compose.full.yml # Complete orchestration
│   ├── services/               # All microservices source code
│   ├── kubernetes/             # K8s deployment manifests
│   ├── proto/                  # gRPC protocol definitions
│   ├── scripts/                # Utility and setup scripts
│   └── docs/                   # Technical documentation
│
├── postman/                    # API testing collection
├── Docs/                       # High-level documentation
│
├── setup.sh                    # Automated setup
├── test.sh                     # Verification suite
├── COMPLETE_SETUP_GUIDE.md     # Comprehensive guide
└── README.md                   # Project overview
```

### Benefits of This Structure

- ✅ **Single Source of Truth**: All services versioned together
- ✅ **Simplified Dependency Management**: Shared configurations and tools
- ✅ **Easier Integration Testing**: All code in one place
- ✅ **Atomic Commits**: Changes across services in single commit
- ✅ **Consistent Tooling**: Shared linters, formatters, CI/CD

---

## 2. Key Architectural Decisions

### A. Environment & Tooling Decisions

#### Local Development Environment

**Decision**: Use WSL2 + Docker Compose for local development

**Rationale**:
- ✅ Consistent environment across Windows machines
- ✅ Docker Compose provides simpler local orchestration
- ✅ Faster iteration without Kubernetes complexity
- ✅ Production deployment uses Kubernetes manifests

**Implementation**: See [COMPLETE_SETUP_GUIDE.md](../COMPLETE_SETUP_GUIDE.md)

#### Container Registry

**Decision**: Build images locally, optional Docker Hub for sharing

**Rationale**:
- Local builds avoid registry complexity for development
- Docker Hub available for team collaboration if needed
- Production would use private registry (ECR, GCR, ACR)

**Implementation**: Images built via `docker compose build`

### B. Communication Protocol Decisions

#### Asynchronous: Apache Kafka

**Decision**: Use Kafka as the primary message bus

**Rationale**:
- ✅ Decouples services for independent scaling
- ✅ Provides message durability (no data loss)
- ✅ Enables replay for debugging
- ✅ Industry-standard for event streaming
- ✅ Supports millions of messages per second

**Topics**:
- `bid_requests` - Raw incoming bid requests
- `bid_responses` - Calculated bid responses
- `auction_outcomes` - Final auction results

#### Synchronous: gRPC for User Profile Service

**Decision**: Use gRPC instead of REST for user profile lookups

**Rationale**:
- ✅ **Performance**: HTTP/2 + Protocol Buffers = sub-5ms calls
- ✅ **Type Safety**: Strongly-typed contracts via `.proto` files
- ✅ **Efficiency**: Binary serialization smaller than JSON
- ✅ **Code Generation**: Auto-generate client/server code
- ⚠️ **Trade-off**: Less human-readable than JSON

**When to use**:
- Critical path operations (bidding logic → user profile)
- High-frequency, low-latency requirements

**When NOT to use**:
- Public-facing APIs (use REST for better compatibility)
- Simple CRUD operations (REST is simpler)

#### Synchronous: REST for Public APIs

**Decision**: Use REST/HTTP for external-facing endpoints

**Rationale**:
- ✅ Universal compatibility
- ✅ Human-readable JSON
- ✅ Easy to test with curl/Postman
- ✅ Well-understood by all developers

**Endpoints**:
- `POST /bid` - Submit bid requests
- `GET /api/outcomes/` - Query analytics
- `GET /healthz` - Health checks

### C. Database Selection

#### Redis for User Profiles

**Decision**: Use Redis as cache for user profile data

**Rationale**:
- ✅ **Speed**: Sub-millisecond read times
- ✅ **Simplicity**: Key-value storage perfect for profiles
- ✅ **Scalability**: Easy to scale with clustering
- ⚠️ **Volatility**: In-memory = data lost on restart (acceptable for cache)

**Schema**: `user-{id}` → JSON string with interests

#### PostgreSQL for Analytics

**Decision**: Use PostgreSQL for analytics data persistence

**Rationale**:
- ✅ **Reliability**: ACID transactions, data durability
- ✅ **Querying**: Rich SQL for analytics and aggregations
- ✅ **Indexing**: Fast queries on win_status, user_id, timestamps
- ✅ **Ecosystem**: Excellent tooling and ORMs (Django ORM)

**Alternative considered**: ClickHouse (better for massive scale, overkill for this scope)

### D. Configuration Management

**Decision**: Environment variables injected via Docker Compose / Kubernetes ConfigMaps

**Rationale**:
- ✅ 12-Factor App principle
- ✅ No hardcoded configuration in source code
- ✅ Easy to override for different environments
- ✅ Kubernetes-native approach

**Examples**:
```yaml
KAFKA_BROKERS: kafka:29092
USER_PROFILE_SVC_ADDR: user-profile-service:50051
DB_HOST: postgres
DB_NAME: helios_analytics
```

---

## 3. Development Phased Approach

**Decision**: Build incrementally in phases, not all at once

**Rationale**:
- ✅ Reduces complexity and debugging scope
- ✅ Validates each component before moving forward
- ✅ Enables early testing and iteration
- ✅ Team can work on different phases in parallel (after initial setup)

### Phase Breakdown

#### Phase 0: Foundation
**Goal**: Infrastructure setup and validation

**Tasks**:
- Set up WSL2 + Docker Desktop
- Verify Docker Compose works
- Deploy infrastructure (Kafka, Redis, PostgreSQL)
- Validate inter-container networking

**Success Criteria**: All infrastructure containers healthy

#### Phase 1: Core Asynchronous Pipeline
**Goal**: Get messages flowing through Kafka

**Services**: Bid Request Handler (Go), Bidding Logic Service (Python)

**Tasks**:
1. Build Bid Request Handler with `/bid` endpoint
2. Publish messages to `bid_requests` topic
3. Build Bidding Logic consumer (no enrichment yet)
4. Verify messages flow end-to-end

**Success Criteria**: `./test.sh` shows messages in Kafka topics

**Documentation**: [helios-rtb-engine/docs/phases/01-core-pipeline.md](../helios-rtb-engine/docs/phases/01-core-pipeline.md)

#### Phase 2: User Enrichment
**Goal**: Add real-time user profile lookups

**Services**: User Profile Service (Node.js)

**Tasks**:
1. Deploy Redis
2. Build gRPC server for user profiles
3. Seed Redis with demo data
4. Modify Bidding Logic to call gRPC endpoint
5. Verify enriched bids with user interests

**Success Criteria**: Bid responses include `enriched: true` and interest scores

#### Phase 3: Auction & Analytics
**Goal**: Complete the pipeline with auction logic and data persistence

**Services**: Auction Simulator, Analytics Service

**Tasks**:
1. Build Auction Simulator consuming from `bid_responses`
2. Implement auction logic (threshold + probability)
3. Build Analytics Service (API + Consumer)
4. Deploy PostgreSQL
5. Verify data persists in database

**Success Criteria**: `curl localhost:8000/api/outcomes/` returns data

**Documentation**: 
- [03-auction-service.md](../helios-rtb-engine/docs/phases/03-auction-service.md)
- [03.2-analytics-service.md](../helios-rtb-engine/docs/phases/03.2-analytics-service.md)

#### Phase 4: Observability & UI
**Goal**: Add monitoring and user interface

**Services**: Advertiser Dashboard

**Tasks**:
1. Build Next.js dashboard
2. Add Prometheus metrics to services
3. Create Grafana dashboards (optional)
4. Add comprehensive logging

**Success Criteria**: Dashboard displays live data from analytics API

**Documentation**: [04-observability-ui.md](../helios-rtb-engine/docs/phases/04-observability-ui.md)

---

## 4. Security & Production Considerations

### Docker Security

**Decision**: All containers run as non-root users

**Implementation**:
```dockerfile
# Final stage creates non-root user
RUN addgroup --system appgroup && adduser --system --group appuser
USER appuser
```

**Rationale**: Defense in depth - container compromise doesn't grant root access

### Secrets Management

**Decision**: Use environment variables for local, Kubernetes Secrets for production

**Current State**: Default credentials in `docker-compose.full.yml`
```yaml
POSTGRES_PASSWORD: admin  # ⚠️ CHANGE IN PRODUCTION
```

**Production Implementation**:
```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-secret
        key: password
```

### Network Security

**Decision**: Services communicate within Docker network / K8s cluster

**Rationale**:
- Only necessary ports exposed to host
- Internal traffic doesn't leave the bridge network
- Production would add TLS/mTLS via service mesh

---

## 5. Testing Strategy

### Automated Testing

**Decision**: Multi-level testing approach

**Levels**:
1. **Unit Tests**: Within each service (Python pytest, Node.js Jest)
2. **Integration Tests**: `test.sh` validates entire pipeline
3. **API Tests**: Postman collection for manual/CI testing
4. **Load Tests**: `populate_demo_data.py` for stress testing

### Health Checks

**Decision**: Every service exposes health endpoint

**Implementation**:
```yaml
healthcheck:
  test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/healthz"]
  interval: 10s
  timeout: 5s
  retries: 3
```

**Rationale**: Docker/Kubernetes can detect and restart unhealthy containers

---

## 6. Monitoring & Observability

### Structured Logging

**Decision**: JSON logs to stdout

**Format**:
```json
{
  "timestamp": "2025-10-30T12:00:00Z",
  "level": "INFO",
  "service": "bidding-logic-service",
  "message": "Bid calculated",
  "bid_price": 1.20,
  "request_id": "req-123"
}
```

**Rationale**:
- ✅ Easy to parse and aggregate
- ✅ Works with standard log collectors (Fluentd, Logstash)
- ✅ Queryable in log analysis tools

### Metrics

**Decision**: Prometheus-compatible metrics endpoints

**Exposed Ports**:
- Bid Handler: `:2112/metrics`
- Bidding Logic: `:8001/metrics`

**Key Metrics**:
- `bid_requests_total` - Counter of total bids
- `bid_requests_duration_seconds` - Histogram of processing time
- `kafka_messages_consumed_total` - Consumer throughput

---

## 7. Future Enhancements

### Machine Learning Integration

**Potential**: Replace rule-based bidding with ML model

**Implementation**:
- Train model on historical auction outcomes
- Predict optimal bid price based on features
- Deploy model as separate service or inline

### Real-Time Dashboard Updates

**Potential**: WebSocket/SSE for live dashboard updates

**Implementation**:
- Add WebSocket server to Analytics Service
- Publish to WS when new outcomes arrive
- Dashboard subscribes and updates charts live

### Advanced Monitoring

**Potential**: Add Prometheus + Grafana stack

**Implementation**:
```bash
kubectl apply -f helios-rtb-engine/kubernetes/infra/prometheus-grafana/
```

### Circuit Breakers

**Potential**: Graceful degradation when services fail

**Implementation**: Use libraries like `resilience4py`, `polly`, or `hystrix`

---

## Summary

This architecture balances:
- **Performance** (Go, gRPC, Redis)
- **Scalability** (Kafka, stateless services)
- **Maintainability** (clear separation, documentation)
- **Observability** (metrics, logs, health checks)
- **Production-readiness** (security, configuration, testing)

For complete setup and deployment, see:
- **[COMPLETE_SETUP_GUIDE.md](../COMPLETE_SETUP_GUIDE.md)** - Full walkthrough
- **[Architecture Overview](../helios-rtb-engine/docs/architecture_and_flow.md)** - Technical details
- **[Phase Documentation](../helios-rtb-engine/docs/phases/)** - Development guides
