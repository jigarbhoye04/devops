# Helios RTB Engine: Global Instructions & Conventions

This document outlines the global rules and coding standards for all services within the Helios project. All generated code and configuration must adhere to these guidelines.

### 1. General Principles
- **Directory Structure:** All code must be placed within the established monorepo structure.
- **Configuration:** All configuration (e.g., database hosts, Kafka topics, service ports) MUST be provided through environment variables. Do not hardcode configuration values. Use Kubernetes ConfigMaps and Secrets to inject these variables.
- **Logging:** All logs must be written to `stdout` as structured JSON. This allows for easy collection and parsing by Fluentd. Each log entry should include a timestamp, log level, and a message.

### 2. Coding Styles
- **Go (`bid-request-handler`):**
  - Use standard `gofmt` for all Go code.
  - Follow idiomatic Go conventions (e.g., explicit error handling).
- **Python (`bidding-logic-service`, `analytics-service`):**
  - Use `Black` for code formatting.
  - Use `Flake8` for linting.
  - Use type hints for all function signatures.
  - All dependencies must be listed in a `requirements.txt` file.
- **Node.js / TypeScript (`user-profile-service`, `advertiser-dashboard`):**
  - Use `Prettier` for code formatting.
  - Use `ESLint` for linting (with a standard configuration like `eslint-config-airbnb-typescript`).
  - Use TypeScript for all backend Node.js services.
  - `Strict Typing`: Always prefer explicit and strict types. The use of any is discouraged and should only be used as a last resort with justification.
  - `React Hooks`: Minimize the use of useEffect. Prefer derived state, memoization, and custom hooks where applicable to reduce unnecessary re-renders and side effects.
  - All dependencies must be listed in `package.json`.

### 3. Dockerfiles
- **Multi-stage Builds:** All Dockerfiles MUST use multi-stage builds to create small, secure production images. The final image should be based on a minimal base (e.g., `alpine`, `distroless`).
- **Non-root User:** The final stage of every Dockerfile should create and run the application as a non-root user for security.

### 4. Kubernetes Manifests
- **Labels:** All resources (Deployments, Services, etc.) MUST have standard labels: `app: helios` and `component: <service-name>`.
- **Naming:** Resource names should be prefixed with the service name (e.g., `bidding-logic-svc-deployment`).
- **Services:** All services that need to communicate within the cluster must have a corresponding `ClusterIP` Service resource defined.

### 5. API Contracts
- **gRPC:** All gRPC services and messages will be defined in `.proto` files within the `/proto` directory.
- **REST:** All public-facing REST APIs should be designed with clear, resource-oriented URLs.