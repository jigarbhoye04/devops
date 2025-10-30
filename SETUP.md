# Helios RTB Engine Local Docker Setup

This guide explains how to run the entire Helios RTB Engine stack on Windows using WSL and Docker, without Kubernetes. All commands in this document assume you are inside your WSL distribution (Ubuntu is recommended) and have the repository checked out at `/mnt/c/Users/Jigar/Documents/GitHub/devops`.

## 1. Prerequisites
- **Windows 11 with WSL 2 enabled.** Run `wsl --install` from an elevated PowerShell session if WSL is not yet configured.
- **Docker Desktop 4.30 or later** with the "Use the WSL 2 based engine" option enabled and your Linux distribution selected under *Resources ▸ WSL Integration*.
- **WSL packages:** `bash`, `curl`, `git`, and `coreutils` (all included in Ubuntu by default).
- **Disk space:** At least 8 GB free for images, containers, and PostgreSQL data.

Verify that `docker` is reachable from WSL:
```bash
$ docker info --format '{{.ServerVersion}}'
```
If this command fails, open Docker Desktop in Windows and ensure the engine is running.

## 2. Repository Layout
Key paths used by the setup script:
- `helios-rtb-engine/docker-compose.full.yml` – Docker Compose definition for all infrastructure and services.
- `helios-rtb-engine/services/` – Source for each microservice.
- `helios-rtb-engine/scripts/` – Utility scripts (e.g., bid request generator).
- `setup.sh` – Automated setup and bootstrap script created for this workflow.

## 3. Quick Start
```bash
wsl
cd /mnt/c/Users/Jigar/Documents/GitHub/devops
chmod +x setup.sh
./setup.sh
```
The script will build all images, start the containers, wait for health checks, create Kafka topics, and seed Redis with sample user profiles. When it finishes, all services listen on localhost ports inside Windows.

## 4. Environment Configuration
Environment variables are injected through `docker-compose.full.yml`. Override defaults by editing that file or by exporting variables before running `setup.sh` (Compose uses standard `${VAR}` substitution if you add references). Key variables by component:

### Core Infrastructure
| Service | Variable | Default | Purpose |
|---------|----------|---------|---------|
| postgres | `POSTGRES_DB` | `helios_analytics` | PostgreSQL database name |
| | `POSTGRES_USER` | `helios` | Database user |
| | `POSTGRES_PASSWORD` | `admin` | Database password |
| kafka | `KAFKA_ADVERTISED_LISTENERS` | `PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092` | Internal and host advertised listeners |
| | `KAFKA_AUTO_CREATE_TOPICS_ENABLE` | `true` | Auto-create topics when they are first used |
| redis | _none_ | — | Uses default port 6379 |

### Bid Request Handler (`services/bid-request-handler`)
| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BROKERS` | `kafka:29092` | Comma-separated broker list |
| `KAFKA_TOPIC_BID_REQUESTS` | `bid_requests` | Kafka topic for inbound bid requests |

### User Profile Service (`services/user-profile-service`)
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | `redis` | Redis hostname inside the compose network |
| `REDIS_PORT` | `6379` | Redis port |
| `PROTO_PATH` | `/app/proto/user_profile.proto` | Location of the generated gRPC definition |

### Bidding Logic Service (`services/bidding-logic-service`)
| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BROKERS` | `kafka:29092` | Kafka bootstrap brokers |
| `KAFKA_TOPIC_BID_REQUESTS` | `bid_requests` | Source topic for bid requests |
| `KAFKA_TOPIC_BID_RESPONSES` | `bid_responses` | Target topic for bid responses |
| `KAFKA_CONSUMER_GROUP` | `bidding-logic-consumers` | Consumer group ID |
| `USER_PROFILE_SVC_ADDR` | `user-profile-service:50051` | gRPC endpoint for user enrichment |
| `USER_PROFILE_SVC_TIMEOUT` | `2.0` | (Optional) Timeout in seconds for profile RPC |
| `METRICS_PORT` | `8001` | Prometheus metrics listener |

### Auction Simulator (`services/auction-simulator`)
| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BROKER` | `kafka:29092` | Kafka bootstrap broker |
| `KAFKA_BID_RESPONSE_TOPIC` | `bid_responses` | Source topic for bid responses |
| `KAFKA_AUCTION_OUTCOME_TOPIC` | `auction_outcomes` | Target topic for simulated outcomes |
| `KAFKA_CONSUMER_GROUP` | `auction-simulator-group` | Consumer group ID |
| `MIN_BID_THRESHOLD` | `0.30` | Minimum price to enter the auction |
| `WIN_PROBABILITY` | `0.7` | Win probability for qualifying bids |

### Analytics Service (`services/analytics-service`)
| Variable | Default | Description |
|----------|---------|-------------|
| `DJANGO_SECRET_KEY` | `dev-secret-key-for-testing` | Django secret key (override for production) |
| `DEBUG` | `False` | Django debug flag |
| `ALLOWED_HOSTS` | `*` | Allowed hosts for API |
| `DB_NAME` | `helios_analytics` | PostgreSQL database name |
| `DB_USER` | `helios` | Database user |
| `DB_PASSWORD` | `admin` | Database password |
| `DB_HOST` | `postgres` | Database host inside compose network |
| `DB_PORT` | `5432` | Database port |
| `KAFKA_BROKERS` | `kafka:29092` | Kafka bootstrap brokers |
| `KAFKA_TOPIC_AUCTION_OUTCOMES` | `auction_outcomes` | Topic for auction outcomes |
| `KAFKA_CONSUMER_GROUP` | `analytics-service-group` | Consumer group ID |
| `DJANGO_SUPERUSER_*` | unset | Optional admin bootstrap variables |

### Advertiser Dashboard (`services/advertiser-dashboard`)
| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `production` | Runtime mode |
| `PORT` | `3000` | Dashboard HTTP port |
| `HOSTNAME` | `0.0.0.0` | Listen address inside container |
| `NEXT_PUBLIC_ANALYTICS_API_URL` | `http://localhost:8000` | External URL for the analytics API |

## 5. Published Ports & Data Paths
| Container | Port | Purpose |
|-----------|------|---------|
| bid-request-handler | `8080` | HTTP ingestion API (`/bid`, `/healthz`) |
| bid-request-handler metrics | `2112` | Prometheus metrics |
| user-profile-service | `50051` | gRPC endpoint |
| bidding-logic-service | `8001` | Prometheus metrics |
| auction-simulator | `9001` | Reserved (not exposed publicly by default) |
| analytics-service-api | `8000` | Django REST API |
| advertiser-dashboard | `3000` | Next.js UI |
| kafka | `9092` | Host access to Kafka |
| postgres | `5432` | Host access to PostgreSQL |
| redis | `6379` | Host access to Redis |

Stateful data persists in the named Docker volume `postgres_data`. Remove it with `docker volume rm postgres_data` if you need a clean database restart.

## 6. Running Individual Services
The Compose definition builds images locally. To rebuild a single service after code changes:
```bash
# Example: rebuild the bidding logic service
wsl
cd /mnt/c/Users/Jigar/Documents/GitHub/devops
COMPOSE_FILE=helios-rtb-engine/docker-compose.full.yml
docker compose -f "$COMPOSE_FILE" build bidding-logic-service
docker compose -f "$COMPOSE_FILE" up -d bidding-logic-service
```

## 7. Troubleshooting
- **Docker resources unavailable:** Restart Docker Desktop in Windows and rerun `./setup.sh`.
- **Port already in use:** Stop conflicting services or change the published port in `docker-compose.full.yml` before running the setup script.
- **Slow startup:** Kafka and analytics containers may take 30–60 seconds to pass their health checks. The script waits up to two minutes before timing out.
- **Reset the environment:**
  ```bash
  wsl
  cd /mnt/c/Users/Jigar/Documents/GitHub/devops
  docker compose -f helios-rtb-engine/docker-compose.full.yml down -v
  ./setup.sh
  ```

## 8. Next Steps
After the stack is online, follow `TEST_AND_VERIFY.md` for end-to-end smoke tests, sample bid injections, and service-level validation commands.
