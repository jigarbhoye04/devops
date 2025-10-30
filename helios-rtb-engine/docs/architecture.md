# Helios RTB Engine Architecture

This document summarizes the high-level design of the Helios real-time bidding (RTB) engine. The architecture is optimized for low-latency decisioning, horizontal scalability, and operational observability.

## Core Workflow

1. **Bid Intake:** The `bid-request-handler` receives HTTP bid requests from the API gateway and publishes them to Kafka.
2. **Enrichment & Decisioning:** The `bidding-logic-service` consumes from Kafka, retrieves a profile via gRPC from the `user-profile-service`, evaluates bidding rules, and emits bid responses.
3. **Auction Simulation:** The auction simulator resolves winning bids and emits outcomes for analytics.
4. **Analytics Pipeline:** The analytics service persists auction outcomes and serves metrics to the advertiser dashboard.

Each service communicates using either Kafka topics for asynchronous workflows or gRPC/REST for synchronous calls. All configuration is injected via environment variables to support twelve-factor principles and Kubernetes deployments.

## Cross-Cutting Concerns

- **Observability:** All services emit structured JSON logs to stdout and expose Prometheus-ready metrics endpoints.
- **Security:** TLS termination occurs at the gateway, and secrets (database credentials, API keys) are sourced from Kubernetes Secrets.
- **Resilience:** Circuit breakers and retries are implemented at network boundaries to protect the bidding pipeline from cascading failures.

For deeper context, including component diagrams and sequence flows, refer to the main project `README.md` at the repository root and the ADRs in `docs/adr/`.
