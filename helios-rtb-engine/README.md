# Helios RTB Engine Monorepo

This monorepo contains the core services, infrastructure manifests, and supporting assets for the Helios real-time bidding (RTB) platform. The structure groups each microservice, shared protocol buffer definitions, Kubernetes manifests, and helper scripts in a single location to simplify local development and multi-service deployments.

## Repository Layout

- `.github/` — CI/CD workflows for building and validating Docker images.
- `docs/` — Architecture notes, setup guides, and architectural decision records.
- `infra/` — Infrastructure-as-Code definitions for non-Kubernetes resources.
- `kubernetes/` — Namespaced Kubernetes manifests for services and shared infrastructure.
- `proto/` — Protocol Buffer definitions shared across services.
- `scripts/` — Utility scripts for provisioning clusters, deploying manifests, and generating sample data.
- `services/` — Source code for each Helios microservice.

Refer to the root-level `README.md` for the broader project vision and roadmap. This document focuses on the monorepo specifics.
