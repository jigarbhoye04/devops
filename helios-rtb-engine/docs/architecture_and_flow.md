# Helios RTB Engine: Architecture and Overall Flow

## Introduction

The Helios RTB (Real-Time Bidding) Engine is a scalable, microservices-based system designed for programmatic advertising auctions. Built as a monorepo with Kubernetes deployment, it processes bid requests in real-time, enriches them with user profiles, executes auctions, and provides analytics for advertisers.

The system is developed in phases, with each phase adding incremental functionality while maintaining operational excellence through structured logging, configuration management, and observability.

## High-Level Architecture

The architecture follows a microservices pattern with asynchronous communication via Apache Kafka. Services are containerized with Docker and deployed on Kubernetes, with all configuration managed through environment variables and ConfigMaps/Secrets.

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   API Gateway   │     │     Kafka       │     │   PostgreSQL    │
│  (Traefik)      │◄────┤   Message Bus   │────►│   Database      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Bid Request     │────►│ Bidding Logic   │────►│ Auction         │
│   Handler       │     │   Service       │     │ Simulator       │
│   (Go)          │     └─────────────────┘     │   (Node.js)     │
└─────────────────┘             │               └─────────────────┘
                                ▼                       │
                       ┌─────────────────┐             ▼
                       │ User Profile    │     ┌─────────────────┐
                       │   Service       │     │   Analytics     │
                       │   (Node.js/TS)  │     │   Service       │
                       └─────────────────┘     │   (Django)      │
                                               └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │ Advertiser      │
                                               │   Dashboard     │
                                               │   (Next.js)     │
                                               └─────────────────┘
```

## Core Components

### 1. Bid Request Handler (Go)
- **Purpose**: HTTP ingestion endpoint for bid requests
- **Technology**: Go with `github.com/segmentio/kafka-go`
- **Responsibilities**:
  - Expose `/bid` and `/healthz` endpoints on port 8080
  - Validate and forward JSON payloads to Kafka `bid_requests` topic
  - Emit structured JSON logs to stdout

### 2. User Profile Service (Node.js/TypeScript)
- **Purpose**: User data management and enrichment
- **Technology**: Node.js with TypeScript, Express.js
- **Responsibilities**:
  - Store and retrieve user profiles via gRPC
  - Provide user interests, demographics, and behavioral data
  - Handle profile creation and updates

### 3. Bidding Logic Service (Python)
- **Purpose**: Bid decisioning and user enrichment
- **Technology**: Python with `kafka-python`
- **Responsibilities**:
  - Consume from `bid_requests` topic
  - Enrich bids with user profiles via gRPC calls
  - Generate bid responses based on user interests
  - Publish to `bid_responses` topic

### 4. Auction Simulator (Node.js)
- **Purpose**: Auction execution and winner determination
- **Technology**: Node.js with `kafkajs`
- **Responsibilities**:
  - Consume from `bid_responses` topic
  - Execute auction logic (threshold-based with probability)
  - Determine winners and publish outcomes to `auction_outcomes` topic

### 5. Analytics Service (Python/Django)
- **Purpose**: Data persistence and reporting
- **Technology**: Django with Django REST Framework
- **Responsibilities**:
  - Consume from `auction_outcomes` topic
  - Persist auction data to PostgreSQL
  - Provide REST API for querying and analytics
  - Generate statistics and aggregations

### 6. Advertiser Dashboard (Next.js)
- **Purpose**: User interface for advertisers
- **Technology**: Next.js with React
- **Responsibilities**:
  - Display auction analytics and performance metrics
  - Provide campaign management interface
  - Visualize bidding data and outcomes

## Overall Data Flow

The complete RTB pipeline processes bid requests through multiple stages:

### Phase 1: Core Asynchronous Pipeline
1. **Bid Request Ingestion**
   - Client sends HTTP POST to `/bid` endpoint
   - Bid Request Handler validates and publishes to `bid_requests` Kafka topic

2. **Asynchronous Processing**
   - Bidding Logic Service consumes from `bid_requests`
   - Processes messages asynchronously for scalability

### Phase 2: User Enrichment
3. **Profile Enrichment**
   - Bidding Logic Service calls User Profile Service via gRPC
   - Retrieves user interests, demographics, and behavioral data
   - Enriches bid request with user context

### Phase 3: Auction Execution
4. **Bid Generation**
   - Bidding Logic Service calculates bid price based on user profile
   - Publishes bid response to `bid_responses` topic

5. **Auction Resolution**
   - Auction Simulator consumes bid responses
   - Applies auction rules (minimum threshold, win probability)
   - Publishes auction outcomes to `auction_outcomes` topic

### Phase 3.2: Analytics Pipeline
6. **Data Persistence**
   - Analytics Service consumes auction outcomes
   - Stores complete auction data in PostgreSQL
   - Provides REST API for data access and analytics

### Phase 4: Observability UI
7. **Dashboard Integration**
   - Advertiser Dashboard queries Analytics API
   - Displays real-time metrics and visualizations
   - Enables campaign optimization

## Message Schemas

### Bid Request
```json
{
  "request_id": "req-123",
  "user_id": "user-456",
  "timestamp": "2025-10-25T12:00:00Z",
  "device_type": "mobile",
  "page_url": "https://example.com"
}
```

### Bid Response
```json
{
  "bid_request_id": "req-123",
  "user_id": "user-456",
  "bid_price": 0.80,
  "currency": "USD",
  "timestamp": "2025-10-25T12:00:01Z",
  "enriched": true,
  "user_interests": ["technology", "sports"]
}
```

### Auction Outcome
```json
{
  "bid_request_id": "req-123",
  "user_id": "user-456",
  "bid_price": 0.80,
  "currency": "USD",
  "timestamp": "2025-10-25T12:00:01Z",
  "enriched": true,
  "user_interests": ["technology", "sports"],
  "win_status": true,
  "win_price": 0.80,
  "auction_timestamp": "2025-10-25T12:00:02Z"
}
```

## Technologies and Frameworks

### Programming Languages
- **Go**: High-performance HTTP services (Bid Request Handler)
- **Python**: Data processing and analytics (Bidding Logic, Analytics Service)
- **Node.js/TypeScript**: API services and user interfaces (User Profile, Auction Simulator, Dashboard)

### Infrastructure
- **Apache Kafka**: Asynchronous message bus
- **PostgreSQL**: Primary data store
- **Redis**: Caching and session storage
- **Kubernetes**: Container orchestration
- **Docker**: Containerization
- **Traefik**: API gateway and load balancer

### Communication Protocols
- **HTTP/REST**: External API communication
- **gRPC**: Internal service-to-service communication
- **Kafka Topics**: Asynchronous event streaming

### Development Tools
- **Docker Multi-stage Builds**: Optimized production images
- **Kubernetes ConfigMaps/Secrets**: Configuration management
- **Structured JSON Logging**: Observability
- **Prometheus/Grafana**: Monitoring and visualization

## Deployment Architecture

### Kubernetes Namespaces
- **helios**: Main application namespace
- Services labeled with `app: helios` and `component: <service-name>`

### Service Types
- **ClusterIP**: Internal service communication
- **LoadBalancer/Ingress**: External access (API Gateway)

### Scaling Strategy
- **Stateless Services**: Horizontal scaling (Bid Handler, User Profile, Auction Simulator)
- **Stateful Services**: Database persistence (PostgreSQL)
- **Event-Driven**: Kafka consumers scale with message volume

### Configuration Management
- **Environment Variables**: All configuration injected at runtime
- **ConfigMaps**: Non-sensitive configuration
- **Secrets**: Sensitive data (database passwords, API keys)

## Monitoring and Observability

### Logging
- **Structured JSON**: All services emit JSON logs to stdout
- **Centralized Collection**: Fluentd aggregates logs
- **Log Levels**: INFO, WARN, ERROR with contextual data

### Metrics
- **Prometheus**: Service metrics collection
- **Custom Metrics**: Request latency, error rates, throughput
- **Business Metrics**: Win rates, average bid prices, revenue

### Visualization
- **Grafana Dashboards**: Real-time monitoring
- **Kibana/ELK**: Log analysis and visualization
- **Custom Dashboards**: Auction performance, system health

### Health Checks
- **Kubernetes Probes**: Readiness and liveness checks
- **Service Endpoints**: `/healthz` endpoints for all services
- **Dependency Checks**: Database connectivity, Kafka reachability

## Security Considerations

### Network Security
- **TLS Termination**: At API gateway
- **Service Mesh**: Istio integration planned
- **Network Policies**: Kubernetes network segmentation

### Data Protection
- **Encryption**: Data encrypted at rest and in transit
- **Secrets Management**: Kubernetes secrets with rotation
- **Access Control**: RBAC for Kubernetes resources

### Application Security
- **Input Validation**: All external inputs validated
- **Rate Limiting**: API gateway rate limiting
- **Authentication**: JWT tokens for dashboard access

## Performance Characteristics

### Latency Targets
- **Bid Request Processing**: <10ms end-to-end
- **User Profile Lookup**: <5ms gRPC calls
- **Auction Resolution**: <10ms per bid
- **Analytics Queries**: <100ms for aggregations

### Throughput
- **Bid Requests**: 10,000+ requests/second
- **Concurrent Users**: 100,000+ active profiles
- **Data Retention**: Configurable retention policies

### Scalability
- **Horizontal Scaling**: All services designed for scale-out
- **Auto-scaling**: Kubernetes HPA based on CPU/memory
- **Database Sharding**: Future consideration for high volume

## Development Workflow

### Phase-Based Development
1. **Phase 1**: Core ingestion pipeline
2. **Phase 2**: User enrichment
3. **Phase 3**: Auction execution
4. **Phase 3.2**: Analytics pipeline
5. **Phase 4**: Observability and UI

### Code Quality
- **Linting**: ESLint, Flake8, gofmt
- **Testing**: Unit tests, integration tests
- **CI/CD**: Automated builds and deployments
- **Code Reviews**: Pull request reviews required

### Documentation
- **Architecture Decision Records**: In `docs/adr/`
- **Phase Documentation**: Detailed implementation guides
- **API Documentation**: OpenAPI specifications
- **Operational Runbooks**: Troubleshooting and maintenance

## Conclusion

The Helios RTB Engine demonstrates a production-ready microservices architecture optimized for real-time bidding workflows. Key architectural decisions include:

- **Asynchronous Processing**: Kafka enables decoupling and scalability
- **Service Isolation**: Independent deployment and scaling of components
- **Configuration Management**: Environment-based configuration for portability
- **Observability First**: Comprehensive logging and monitoring from day one
- **Incremental Development**: Phased approach allows for iterative improvement

The system successfully balances performance requirements (low latency, high throughput) with operational excellence (monitoring, security, maintainability). Future enhancements will focus on advanced analytics, machine learning integration, and expanded dashboard capabilities.</content>
<parameter name="filePath">c:\Users\Jigar\Documents\GitHub\devops\helios-rtb-engine\docs\architecture_and_flow.md