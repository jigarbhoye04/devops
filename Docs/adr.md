### 1. Monorepo Directory Structure

For a project with this many interconnected services, a **monorepo** (a single repository containing all the project code) is highly recommended. It simplifies dependency management, versioning, and running integration tests.

```
/helios-rtb-engine/
|
├── .github/                # CI/CD workflows (e.g., build Docker images on push)
|
├── .gitignore
├── README.md               # High-level project overview and setup instructions
|
├── docs/                   # Project documentation
|   ├── architecture.md     # The comprehensive design document you're reading now
|   ├── adr/                # Architectural Decision Records (e.g., "Why we chose gRPC over REST")
|   └── setup-guide.md      # Detailed guide for setting up the K8s cluster
|
├── infra/                  # Infrastructure-as-Code for non-K8s resources (if any)
|
├── kubernetes/             # All Kubernetes deployment manifests (YAML files)
|   ├── 00-namespace.yaml   # Creates the 'helios' namespace for the project
|   |
|   ├── infra/              # Manifests for core infrastructure
|   |   ├── kafka/
|   |   ├── redis/
|   |   ├── postgres/
|   |   └── prometheus-grafana/
|   |
|   ├── services/           # Manifests for your application microservices
|   |   ├── 01-bid-request-handler/
|   |   |   ├── deployment.yaml
|   |   |   └── service.yaml
|   |   ├── 02-user-profile-service/
|   |   |   ├── deployment.yaml
|   |   |   ├── service.yaml
|   |   |   └── configmap.yaml
|   |   ├── ... (and so on for each service)
|   |
|   └── gateway/            # Manifests for the API Gateway (e.g., Traefik, Kong)
|       ├── deployment.yaml
|       └── ingressroute.yaml
|
├── proto/                  # Central location for all Protocol Buffer definitions
|   └── user_profile.proto  # The contract for your gRPC service
|
├── scripts/                # Helper scripts
|   ├── setup_cluster.sh    # Script to automate setting up the local K8s cluster
|   ├── generate_data.py    # Python script to generate mock bid requests and user profiles
|   └── deploy_all.sh       # A simple script to run `kubectl apply` on the entire /kubernetes dir
|
└── services/               # The source code for each individual microservice
    |
    ├── bid-request-handler/  (Go)
    |   ├── main.go
    |   ├── go.mod
    |   ├── Dockerfile
    |   └── .dockerignore
    |
    ├── bidding-logic-service/ (Python)
    |   ├── src/
    |   ├── requirements.txt
    |   ├── Dockerfile
    |   └── .dockerignore
    |
    ├── user-profile-service/ (Node.js)
    |   ├── src/
    |   ├── package.json
    |   ├── tsconfig.json
    |   ├── Dockerfile
    |   └── .dockerignore
    |
    ├── ... (and so on for analytics, auction-simulator)
    |
    └── advertiser-dashboard/ (Next.js)
        ├── pages/
        ├── components/
        ├── package.json
        ├── Dockerfile
        └── .dockerignore
```

---

### 2. Things to Know & Decide Before Jumping In

This is your pre-flight checklist. Agreeing on these points as a team will prevent significant friction.

#### A. Environment & Tooling

1.  **Consistent Local Environment:** Your biggest challenge is consistency across 3 laptops.
    *   **Docker Desktop:** Everyone MUST have Docker Desktop installed. It comes with a local Kubernetes engine which can be enabled.
    *   **Kubernetes for Laptops:** Decide on your K8s distribution. **k3s** is a lightweight, certified distribution perfect for this. You can set up one laptop as the master and have the others join as worker nodes over your local WiFi. **This is a crucial first step. Document the process in `docs/setup-guide.md`.**
    *   **Shared Docker Registry:** To share Docker images between your laptops, you can use Docker Hub or set up a local Docker registry on the master node. This is much faster than pushing/pulling from the internet.

2.  **API Contracts First:** Do NOT start coding the services immediately.
    *   **gRPC:** Define the `user_profile.proto` file first. Agree on the service methods, request, and response messages. Generate the client and server stubs for both Node.js and Python from this file.
    *   **REST APIs:** Use the **OpenAPI (Swagger) specification** to define the REST APIs for the `Bid Request Handler` and the `Analytics Service`. This provides clear documentation and allows you to generate API clients.

3.  **Configuration Management:** How will services know where Kafka or Redis is?
    *   **Kubernetes ConfigMaps:** For non-sensitive configuration like the address of another service (e.g., `kafka-service.helios.svc.cluster.local:9092`).
    *   **Kubernetes Secrets:** For all sensitive data (database passwords, API keys).
    *   **Environment Variables:** Services should read their configuration from environment variables. Kubernetes will populate these variables from ConfigMaps and Secrets. This is a core principle of 12-Factor Apps.

#### B. The Phased Development Plan (Crucial for Success)

Do not try to build everything at once. Build a "walking skeleton" of the data pipeline and then add features.

*   **Phase 0: Foundation (The Plumbing)**
    *   **Goal:** Set up the multi-node K8s cluster across your laptops.
    *   **Tasks:** Install k3s, connect the nodes. Deploy Kafka and a tool like `k9s` or `Lens` to inspect the cluster. Prove that a simple "hello-world" pod on one node can talk to another pod on a different node.

*   **Phase 1: The Core Asynchronous Pipeline**
    *   **Goal:** Get a message from the entry point to the end point via Kafka.
    *   **Tasks:**
        1.  Build the `Bid Request Handler` (Go). It should only receive an HTTP request and publish its body to the `bid_requests` Kafka topic.
        2.  Build the `Bidding Logic Service` (Python). It should only consume from `bid_requests`, log the message, and do nothing else.
        3.  Containerize and deploy both. Use your `generate_data.py` script to send a fake bid request and verify it appears in the logs of the Bidding Logic Service.

*   **Phase 2: Adding Real-time Context (The gRPC Call)**
    *   **Goal:** Integrate the low-latency data enrichment step.
    *   **Tasks:**
        1.  Deploy Redis to the cluster.
        2.  Build the `User Profile Service` (Node.js) with its gRPC endpoint. It should be able to read/write mock data to Redis.
        3.  Modify the `Bidding Logic Service` to make a gRPC call to the `User Profile Service`.
        4.  Test the end-to-end latency. This is where you'll use tracing tools later.

*   **Phase 3: Closing the Loop (Auction & Analytics)**
    *   **Goal:** Complete the data flow and persist the results.
    *   **Tasks:**
        1.  Build the `Auction Service` and `Analytics Service`.
        2.  Deploy PostgreSQL.
        3.  Modify the Bidding Logic service to produce a bid response.
        4.  Ensure the auction outcomes are correctly written to the PostgreSQL database.

*   **Phase 4: Observability & User Interface**
    *   **Goal:** Add monitoring and a way to view the data.
    *   **Tasks:**
        1.  Deploy the Prometheus/Grafana stack. Add metrics endpoints to your key services.
        2.  Build the `Advertiser Dashboard` (Next.js) to query the Analytics Service API.
