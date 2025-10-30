# Phase 1 – Core Asynchronous Pipeline

## Goal
Deliver a reliable, minimally viable real-time bidding ingestion loop that accepts HTTP bid requests, publishes them asynchronously to Kafka, and processes them with a downstream consumer so future enrichment and decisioning logic can be added safely.

## Components Built

### Bid Request Handler (Go)
- Exposes `/bid` and `/healthz` endpoints on port `8080`.
- Validates and forwards incoming JSON payloads to Kafka using `github.com/segmentio/kafka-go`.
- Emits structured JSON logs to stdout for observability in Kubernetes.

### Bidding Logic Service (Python)
- Subscribes to the `bid_requests` topic and streams messages using `kafka-python`.
- Loads all configuration from environment variables (via ConfigMaps) and emits structured logs.
- Provides a foundation for future bidding strategies and analytics fan-out.

## Key Technologies Used & Why
- **Apache Kafka:** Durable message broker that decouples the HTTP ingest path from downstream processing.
- **Docker Multi-stage Builds:** Produce repeatable, slim images for both services with non-root execution.
- **Kubernetes Deployments & Services:** Provide scaling, self-healing, and stable service discovery within the cluster.
- **ConfigMaps & Environment Variables:** Centralize configuration (brokers, topics, consumer groups) without hardcoding values in images.

## Data Flow Overview
```
Client HTTP Request
        |
        v
+----------------------+       +------------------------------+
| Bid Request Handler | ----> | Kafka Topic: bid_requests     |
|  (Go HTTP service)  |       |  Service: kafka-service       |
+----------------------+       +------------------------------+
                                        |
                                        v
                         +------------------------------+
                         | Bidding Logic Service (Py)   |
                         |  Kafka consumer & processor  |
                         +------------------------------+
```

## Verification
Follow the operational checklist to validate this phase end-to-end:

[How to Verify This Phase](../testing/phase-1-verification.md)
