# Helios RTB Engine: 

### **Phase-Wise Development Prompts**

Now, here are the detailed prompts for the LLM to execute, phase by phase.

#### **Phase 0: Project Scaffolding & Foundation**

**Prompt 0.1: Create Monorepo Structure**
**Goal:** Initialize the project with the correct directory and file structure.
**Task:** Create the following directory and file structure. Files can be empty unless content is specified.

```
/helios-rtb-engine/
|
├── .github/                # CI/CD workflows (e.g., build Docker images on push)
|
├── .gitignore
├── README.md               # High-level project overview and setup instructions (keep existing things intact, add any new addition in continuation to that)
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

Provide the content for `.gitignore` (common for Node, Python, Go).
NOTES: Some starter code is already added like linting, prettier configs, basic Dockerfiles, etc. You can enhance them as needed.(existing frontend 0 nextjs service (u just have to move it to services/advertiser-dashboard and add Dockerfile and .dockerignore)) and similar things.

**Prompt 0.2: Kubernetes Namespace & Core Infra Placeholders**
**Goal:** Create the logical namespace in Kubernetes for the project and placeholder files for infrastructure deployment.
**Task:**
1.  Create the file `kubernetes/00-namespace.yaml` to define a Kubernetes namespace named `helios`.
2.  Create placeholder YAML files for our core infrastructure: `kubernetes/infra/kafka.yaml`, `kubernetes/infra/redis.yaml`, and `kubernetes/infra/postgres.yaml`. For now, these files can contain a simple comment like `# Kafka deployment manifest will be defined here.`

**Prompt 0.3: Data Generation Script**
**Goal:** Create a script to generate realistic mock data for testing the pipeline.
**Task:** Create the file `scripts/generate_data.py`. This Python script should contain a function that generates a JSON object representing a bid request. The object should include fields like `id`, `user: {id: "..."}`, `site: {domain: "..."}`, and `ad_slots: [{...}]`. The script should be runnable from the command line and print one JSON object to standard output.

---

#### **Phase 1: The Core Asynchronous Pipeline**

**Prompt 1.1: Develop the Go Bid Request Handler**
**Goal:** Build the high-performance entry point for all bid requests.
**Task:**
1.  Navigate to `services/bid-request-handler/`.
2.  Create a `go.mod` file for managing dependencies (e.g., a Kafka client library like `segmentio/kafka-go`).
3.  Create the `main.go` file. This application must:
    *   Initialize a Kafka producer. The Kafka broker address (`KAFKA_BROKERS`) and topic name (`KAFKA_TOPIC_BID_REQUESTS`) must be read from environment variables.
    *   Start an HTTP server on port 8080.
    *   Define a POST `/bid` endpoint that reads the request body.
    *   Publish the received body as a message to the specified Kafka topic.
    *   Log all operations in a structured JSON format to `stdout`.
    *   Return a `202 Accepted` status code upon successful publishing.

**Prompt 1.2: Containerize the Go Bid Request Handler**
**Goal:** Create a production-ready Docker image for the Go service.
**Task:** Create a `Dockerfile` in `services/bid-request-handler/`. It must be a multi-stage build. The first stage builds the Go binary, and the final stage copies the compiled binary into a minimal `alpine` image and runs it as a non-root user.

**Prompt 1.3: Develop the Python Bidding Logic Skeleton**
**Goal:** Build a consumer that can receive and acknowledge messages from the pipeline.
**Task:**
1.  Navigate to `services/bidding-logic-service/`.
2.  Create a `requirements.txt` file listing dependencies (e.g., `kafka-python`).
3.  Create a `src/main.py` file. This application must:
    *   Initialize a Kafka consumer. The Kafka broker address (`KAFKA_BROKERS`), topic name (`KAFKA_TOPIC_BID_REQUESTS`), and consumer group ID must be read from environment variables.
    *   Enter a loop to continuously poll for messages from the Kafka topic.
    *   For each message received, log its content (the bid request) in a structured JSON format to `stdout`.

**Prompt 1.4: Containerize and Deploy Phase 1 Services**
**Goal:** Create the Kubernetes manifests required to deploy and connect the two services built in this phase.
**Task:**
1.  Create the `Dockerfile` for the `bidding-logic-service`. It must be a multi-stage build using a Python slim base image.
2.  Create a directory `kubernetes/services/01-bid-request-handler/`. Inside, create `deployment.yaml` and `service.yaml`. The deployment should manage 2 replicas and inject the Kafka environment variables from a ConfigMap. The service should expose port 8080.
3.  Create a directory `kubernetes/services/03-bidding-logic-service/`. Inside, create `deployment.yaml`. It should manage 2 replicas and also get its Kafka configuration from the same ConfigMap.
4.  Create `kubernetes/infra/configmap.yaml` to store the shared configuration, like the Kafka broker address (`kafka-service.helios.svc.cluster.local:9092`).

**Prompt 1.5: Verification Plan for Phase 1**
**Goal:** Provide instructions to test and verify the end-to-end functionality of the core pipeline.
**Task:** Create a markdown file `docs/testing/phase-1-verification.md` that lists the `kubectl` and `curl` commands to:
1.  Deploy all the manifests created in this phase.
2.  Port-forward the `bid-request-handler` service to localhost.
3.  Use the `generate_data.py` script piped to `curl` to send a test request.
4.  Check the logs of one of the `bidding-logic-service` pods to confirm the message was received and logged.

---

##### **Improved Prompt for Phase 1 Wrap-up**

**Prompt 1.5 (Revised): Verification Plan & Phase 1 Documentation**

**Goal:** To create a clear, repeatable verification plan for the core pipeline and to produce comprehensive, user-friendly documentation that summarizes the architecture and functionality of Phase 1.

---

**Task 1: Create the Verification Plan**

Create a markdown file at `docs/testing/phase-1-verification.md`. This file is a technical checklist for developers to test the pipeline. It must contain the precise `kubectl` and `curl` commands, along with expected outputs, to perform the following steps:

1.  **Prerequisites:** List the required tools (e.g., `kubectl`, `Docker`, a running Kubernetes cluster).
2.  **Build Images:** Provide the `docker build` commands for both the `bid-request-handler` and `bidding-logic-service`.
3.  **Deploy Manifests:** List the `kubectl apply` commands needed to deploy the namespace, the shared ConfigMap, and the deployments/services for both microservices.
4.  **Check Pod Status:** Show the `kubectl get pods` command to verify that all pods are in the `Running` state.
5.  **Port-Forward:** Provide the exact `kubectl port-forward` command to expose the `bid-request-handler` service on a local port (e.g., 8080).
6.  **Send Test Data:** Demonstrate how to use the `scripts/generate_data.py` script piped to `curl` to send a single test bid request to the port-forwarded service.
7.  **Verify Logs:**
    *   Show how to get the name of one of the `bidding-logic-service` pods.
    *   Provide the `kubectl logs` command to stream the logs from that pod.
    *   Include a sample of the expected JSON log output to confirm that the message sent in the previous step was successfully received and logged by the consumer.

---

**Task 2: Create Phase 1 Architectural Summary**

**Goal:** To onboard new contributors by explaining the "what, why, and how" of the system built in Phase 1.

Create a new markdown file at `docs/phases/01-core-pipeline.md`. This document should be written in simple, clear language and serve as an architectural guide. It must include the following sections:

1.  **Phase 1 Goal:**
    *   Start with a one-sentence summary: "The goal of Phase 1 was to build a reliable, asynchronous data pipeline that can ingest a message at a web endpoint and have it be processed by a downstream service."

2.  **Components Built in This Phase:**
    *   Use a table or list to describe the two services created:
        *   **Bid Request Handler (Go):** Explain its role as the high-performance "front door" of our system. Mention that it accepts HTTP requests and immediately publishes them to Kafka.
        *   **Bidding Logic Service (Python):** Explain its role as the first "consumer" in the pipeline. Mention that its only job in this phase is to listen for messages from Kafka and log them.

3.  **Key Technologies Used & Why:**
    *   **Kafka:** Explain *why* we chose Kafka. Describe it as the "central nervous system" of our application. Explain that it decouples our services, so the Go service doesn't need to know about the Python service, which makes the system resilient and scalable.
    *   **Docker:** Explain that we use Docker to package each service into a "box" that contains everything it needs to run. This ensures it works the same way everywhere.
    *   **Kubernetes:** Explain that Kubernetes is our "orchestrator" or "manager." It takes our Docker boxes and is responsible for running them, making sure they stay healthy, and helping them talk to each other inside the cluster.
    *   **ConfigMap:** Explain that the `ConfigMap` is like a shared settings file for our services running in Kubernetes, so we don't have to write the Kafka address in multiple places.

4.  **The Data Flow (Diagram):**
    *   Create a simple text-based flow diagram to visualize the process:
        ```
        [User/Test Script]
              |
              | 1. Sends HTTP POST request with JSON data
              v
        [Bid Request Handler (Go Service)]
              |
              | 2. Receives request, returns '202 Accepted'
              | 3. Publishes the JSON data to a Kafka topic ('bid_requests')
              v
        [<<<<<<<<<<< Kafka Message Bus >>>>>>>>>>>]
              |
              | 4. Bidding Logic Service is subscribed to the topic
              v
        [Bidding Logic Service (Python Service)]
              |
              | 5. Consumes the message from Kafka
              | 6. Logs the message content to its console
              v
        [End of Flow]
        ```

5.  **How to Verify This Phase:**
    *   Conclude with a link to the `phase-1-verification.md` file you created in Task 1, stating that it contains the exact commands to run and test everything built in this phase.



### **Phase 2: Adding Real-time Context (The gRPC Call)**

**Prerequisite:** Phase 1 is complete. The core asynchronous pipeline is functional.

**Prompt 2.1 (Revised): Define a Rich gRPC Contract**

**Goal:** To create an authoritative and richly structured ProtoBuf definition for the User Profile service. This contract should provide detailed, meaningful data to enable sophisticated bidding logic, superseding the previous simpler version.

**Task:**
1.  Navigate to the `/proto` directory.
2.  Open the file `user_profile.proto` and replace its entire content with the following superior, structured definition:

    ```protobuf
    syntax = "proto3";

    package helios.userprofile;

    // Option for Go code generation, adjust if your module path is different.
    option go_package = "github.com/your-username/helios-rtb-engine/proto/userprofile";

    // The UserProfileService provides detailed user context for bidding decisions.
    service UserProfileService {
      // Retrieves a user's profile based on their ID.
      rpc GetUserProfile (GetUserProfileRequest) returns (GetUserProfileResponse);
    }

    message GetUserProfileRequest {
      string user_id = 1;
    }

    // Represents a single, scored user interest.
    message Interest {
      // The category of interest, e.g., "sports", "automotive".
      string category = 1;
      // A score from 0.0 to 1.0 indicating the strength of the interest.
      double score = 2;
    }

    // A comprehensive user profile containing multiple signals for ad targeting.
    message UserProfile {
      string user_id = 1;
      // The user's locale, e.g., "en-US".
      string locale = 2;
      // A list of all known interests for the user.
      repeated Interest interests = 3;
      // Other key-value demographic data, e.g., "age_bracket": "25-34".
      map<string, string> demographics = 4;
    }

    message GetUserProfileResponse {
      // The complete user profile object.
      UserProfile profile = 1;
    }
    ```

3.  **Add a comment in the file** explaining the design choice: `// This richer data model is chosen to enable more sophisticated bidding logic by providing scored interests and explicit fields.`


**`Prompt 2.2 (Revised)`: Develop the Node.js User Profile Service**

**Goal:** Build the high-performance gRPC server that provides user data from a Redis cache, adhering to the rich, nested data structure defined in our proto contract.

**Task:**

1.  Navigate to `services/user-profile-service/`.
2.  Create `package.json`. Add dependencies for `@grpc/grpc-js`, `@grpc/proto-loader`, `redis`, `typescript`, `ts-node`, and necessary build tools.
3.  Create `tsconfig.json` for the TypeScript project.
4.  Write the application logic in `src/server.ts`. This application must:
    *   Load the `user_profile.proto` definition.
    *   Implement the `GetUserProfile` RPC handler. This handler will:
        *   Receive a `GetUserProfileRequest`.
        *   Use the `user_id` to query a Redis database. The Redis host and port must be read from `REDIS_HOST` and `REDIS_PORT` environment variables.
        *   If the user profile is found in Redis (it will be stored as a JSON string), parse it and construct the **nested `GetUserProfileResponse`**. The response object must match the proto structure, e.g., `{ profile: { user_id: '...', locale: '...', interests: [{ category: '...', score: 0.9 }], demographics: {...} } }`.
        *   If not found, return a response with an empty `profile` object.
        *   Log the request and the constructed response in structured JSON to `stdout`.
    *   Create and start a gRPC server on port 50051.

---

**`Prompt 2.3 (Revised)`: Implement a Data Seeding Script for Redis**

**Goal:** Create a script to populate the Redis cache with mock user data that matches the rich proto contract, enabling realistic testing.

**Task:**

1.  Navigate to `services/user-profile-service/`.
2.  Create a script `src/seed_redis.ts`.
3.  This script should:
    *   Connect to the Redis server (configured via environment variables).
    *   Generate 5-10 mock user profiles. Each profile **must match the rich structure defined in the proto**, including a `user_id`, a `locale`, a `demographics` map, and an `interests` array where each element is an object with a `category` (string) and a `score` (float, e.g., 0.85).
    *   Store each complete profile object in Redis as a JSON string, using the `user_id` as the key.
    *   Log a confirmation message upon successful seeding.
4.  Add a "seed" script to `package.json` to run this seeder.

---


**Prompt 2.4: Containerize and Deploy Phase 2 Services**
**Goal:** Create the Kubernetes manifests to deploy the new service and its Redis dependency.
**Task:**
1.  Create the `Dockerfile` for the `user-profile-service`. It must be a multi-stage build that first compiles the TypeScript to JavaScript and then copies the output into a minimal `node:alpine` image. Ensure it runs the `seed` script as a post-start hook or as a one-off Kubernetes Job.
2.  In `kubernetes/infra/redis.yaml`, define a `Deployment` for a single Redis instance and a `Service` named `redis-service` that exposes the Redis port within the cluster.
3.  Create a directory `kubernetes/services/03-user-profile-service/`.
4.  Inside, create `deployment.yaml` and `service.yaml`. The deployment should manage 2 replicas and inject the `REDIS_HOST` environment variable. The service should expose the gRPC port 50051.


**`Prompt 2.5 (Revised)`: Integrate gRPC Client into Bidding Logic Service**

**Goal:** Modify the core Python service to enrich bid requests with the detailed, structured user data from the gRPC service.

**Task:**

1.  Modify `services/bidding-logic-service/requirements.txt` to add `grpcio` and `grpcio-tools`.
2.  Add a build step (e.g., in a script or Makefile) to generate the Python gRPC stubs from `proto/user_profile.proto` into the `src` directory.
3.  Modify `services/bidding-logic-service/src/main.py`. For each message consumed from Kafka:
    *   Extract the `user_id` from the bid request.
    *   Create a gRPC client that connects to the `user-profile-service` (address configured via `USER_PROFILE_SVC_ADDR` env var).
    *   Call the `GetUserProfile` method with the `user_id`.
    *   Log the original bid request and the **entire `GetUserProfileResponse` object**. The enriched data will be accessible via the nested `response.profile` attribute (e.g., `response.profile.locale` or `response.profile.interests[0].score`).
    *   **Crucially, implement a circuit breaker** (using a library like `pybreaker`). If the gRPC call fails or times out, the breaker should open, and the service should log an error and proceed without enrichment instead of crashing.

---

**`Prompt 2.6 (Revised)`: Verification Plan for Phase 2**

**Goal:** Provide instructions to test and verify the entire enrichment pipeline, ensuring the logs reflect the new, richer data structure.

**Task:**

Create a markdown file at `docs/testing/phase-2-verification.md` that lists the `kubectl` commands to:
1.  Deploy the Redis and `user-profile-service` manifests.
2.  Run the Redis seeding job and verify the structured data is present using `redis-cli`.
3.  Update the `bidding-logic-service` deployment with the new image and environment variables.
4.  Send a test bid request (as in Phase 1).
5.  Check the logs of the `bidding-logic-service` pod to confirm it now contains the enriched user profile data. The logged output for the profile should **reflect the new, nested structure**. For example:
    ```json
    "enriched_profile": {
      "profile": {
        "user_id": "user-123",
        "locale": "en-US",
        "interests": [
          { "category": "sports", "score": 0.95 },
          { "category": "finance", "score": 0.7 }
        ],
        "demographics": { "age_bracket": "35-44" }
      }
    }
    ```
6.  Test the circuit breaker by deleting the `user-profile-service` pods and observing that the `bidding-logic-service` continues to run and logs the gRPC call failure.


---

### **Phase 3: Closing the Loop (Auction & Analytics)**

**Prerequisite:** Phase 2 is complete. Bid requests are being successfully enriched.

**Prompt 3.1: Develop the Auction Service Simulator**
**Goal:** Create a service that simulates the auction process and determines a winner.
**Task:**
1.  Navigate to `services/auction-service/`.
2.  Create a Node.js (JavaScript) application.
3.  This application must:
    *   Consume from the `bid_responses` Kafka topic (to be created by the Bidding Logic service).
    *   For each bid response message, perform a simple "auction": log the bid and decide if it "won" (e.g., using a random chance or if the bid price > a threshold).
    *   Produce a new message to an `auction_outcomes` Kafka topic. This message should be a JSON object containing the original bid details plus a `win_status` (boolean) and a `win_price` (float).
    *   All Kafka configuration must come from environment variables.

**Prompt 3.2: Develop the Python Analytics & Reporting Service**
**Goal:** Build a service to consume the final auction results and persist them for analysis.
**Task:**
1.  Navigate to `services/analytics-service/`.
2.  Create a Python Django project.
3.  Define a Django model for `AuctionOutcome` with fields for `bid_id`, `user_id`, `site_domain`, `win_status`, `win_price`, and a `timestamp`.
4.  Create a background management command (`manage.py process_outcomes`) that:
    *   Consumes messages from the `auction_outcomes` Kafka topic.
    *   For each message, creates and saves a new `AuctionOutcome` instance to the PostgreSQL database.
    *   Database connection details (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, etc.) must be read from environment variables.
5.  Create a simple Django REST Framework API endpoint (`/api/outcomes/`) that allows read-only list and retrieve access to the stored auction outcomes.

**`Prompt 3.3 (Revised)`: Modify Bidding Logic Service to Produce Bids**

**Goal:** Update the Bidding Logic service to complete its primary function by implementing a more sophisticated bidding strategy that leverages the rich, scored data from the user profile.

**Task:**

1.  Modify `services/bidding-logic-service/src/main.py`.
2.  After receiving the enriched user profile from the `GetUserProfile` gRPC call, implement a more sophisticated bidding rule that **leverages the scored interests** from `response.profile.interests`. For example:
    *   Find the user's interest with the highest `score`.
    *   If the highest interest score is greater than 0.9, set the bid price to $0.10.
    *   If the highest interest score is between 0.7 and 0.9, set the bid price to $0.05.
    *   Otherwise, bid a default minimum of $0.01 (or do not bid).
3.  Create a Kafka producer within the service.
4.  Produce a message to the `bid_responses` Kafka topic. The message should be a JSON object containing the `bid_request_id`, the calculated `bid_price`, and an ad creative to be shown.

**Prompt 3.4: Containerize and Deploy Phase 3 Services**
**Goal:** Get all remaining backend services running in the Kubernetes cluster.
**Task:**
1.  Create Dockerfiles for the `auction-service` and `analytics-service` following the established multi-stage, non-root conventions.
2.  In `kubernetes/infra/postgres.yaml`, define a `StatefulSet` for PostgreSQL, a `PersistentVolumeClaim` for its data, a `Service` to expose it, and a `Secret` to hold the database password.
3.  Create Kubernetes manifests (`deployment.yaml`, `service.yaml`) for the `auction-service` and `analytics-service` in their respective directories under `kubernetes/services/`.
4.  Ensure all necessary Kafka and database environment variables are injected into the deployments from the ConfigMap and Secret. The `analytics-service` deployment should run the `migrate` command as an init container and the `process_outcomes` command as its main process.

**Prompt 3.5: Verification Plan for Phase 3**
**Goal:** Provide instructions to test the full, end-to-end data flow from bid to persisted analytic.
**Task:** Create a markdown file `docs/testing/phase-3-verification.md` with instructions to:
1.  Deploy the PostgreSQL, `auction-service`, and `analytics-service` manifests.
2.  Update the `bidding-logic-service` deployment.
3.  Send a test bid request.
4.  Check the logs of all services in the chain (`bid-request-handler` -> `bidding-logic` -> `auction-service` -> `analytics-service`) to trace the flow of the request.
5.  Port-forward the `analytics-service` API endpoint and use `curl` to verify that a new auction outcome record has been created and is retrievable.

---

### **Phase 4: Observability & User Interface**

**Prerequisite:** Phase 3 is complete. The entire backend pipeline is operational.

**Prompt 4.1: Develop the Next.js Advertiser Dashboard**
**Goal:** Create a user-facing web application to visualize the analytics data.
**Task:**
1.  Navigate to `services/advertiser-dashboard/`.
2.  Create a main page that:
    *   Fetches data from the `analytics-service` API endpoint (`/api/outcomes/`) on the client-side. The API's address should be configured via a runtime environment variable.
    *   Displays the auction outcomes in a simple table.
    *   (Bonus) Add a simple chart (using a library like `recharts`) to show a metric like "Win Rate over Time".

**Prompt 4.2: Containerize and Deploy the Dashboard & API Gateway**
**Goal:** Expose the frontend and backend APIs to the outside world securely.
**Task:**
1.  Create a `Dockerfile` for the `advertiser-dashboard` Next.js application.
2.  Create Kubernetes manifests for the dashboard's `deployment.yaml` and `service.yaml`.
3.  In `kubernetes/gateway/`, create manifests for an API Gateway (e.g., Traefik or Kong).
4.  Define `Ingress` or `IngressRoute` resources to:
    *   Route requests to `/bid` to the `bid-request-handler-service`.
    *   Route requests to `/api/analytics/` to the `analytics-service`.
    *   Route all other requests (`/`) to the `advertiser-dashboard-service`.

**Prompt 4.3: Implement the Monitoring Stack**
**Goal:** Deploy Prometheus and Grafana to achieve observability into the system's health and performance.
**Task:**
1.  In `kubernetes/infra/prometheus-grafana.yaml`, add manifests to deploy Prometheus and Grafana (using a community Helm chart or standard manifests is acceptable).
2.  Configure Prometheus with service discovery annotations so it automatically finds and scrapes metrics from your application pods.
3.  For **at least two** of your backend services (e.g., `bid-request-handler` and `bidding-logic-service`):
    *   Add a Prometheus client library to their dependencies.
    *   Expose a `/metrics` endpoint.
    *   Instrument the code to export at least two custom metrics (e.g., a counter for `bid_requests_total` and a histogram for `request_processing_duration_seconds`).
4.  Create a simple, pre-configured Grafana dashboard (as JSON in a ConfigMap) to visualize the custom metrics you created.

**Prompt 4.4: Final Verification Plan**
**Goal:** Provide instructions for a final, holistic test of the entire deployed system.
**Task:** Create `docs/testing/final-verification.md` with instructions to:
1.  Deploy the dashboard, gateway, and monitoring stack.
2.  Access the Grafana dashboard via the gateway and confirm it is scraping metrics.
3.  Access the advertiser dashboard in a web browser via the gateway's address.
4.  Generate a high volume of bid requests using a script.
5.  Observe the metrics in Grafana change in real-time.
6.  Observe the data on the advertiser dashboard updating to reflect the new auction outcomes.