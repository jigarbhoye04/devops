#!/usr/bin/env bash
# Automated WSL setup for the Helios RTB Engine Docker deployment.
# Usage: ./setup.sh [--reset] [--skip-build]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
COMPOSE_FILE="$REPO_ROOT/helios-rtb-engine/docker-compose.full.yml"
ENV_HINT_FILE="$REPO_ROOT/helios-rtb-engine/.env.helios"

RESET_STACK=0
SKIP_BUILD=0

usage() {
  cat <<'EOF'
Usage: ./setup.sh [options]

Options:
  --reset        Stop containers and remove volumes before rebuilding
  --skip-build   Reuse existing images instead of rebuilding
  -h, --help     Show this help message
EOF
}

log() {
  printf '[setup] %s\n' "$*"
}

warn() {
  printf '[setup][warn] %s\n' "$*" >&2
}

fail() {
  printf '[setup][error] %s\n' "$*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Required file not found: $path"
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
  elif docker-compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
  else
    fail "Docker Compose is not available. Install Docker Desktop with Compose support."
  fi
}

check_wsl() {
  if [[ -f /proc/version ]] && ! grep -qi 'microsoft' /proc/version; then
    warn "WSL not detected. The project is intended to run from WSL; continue at your own risk."
  fi
}

ensure_docker_engine() {
  if ! docker info >/dev/null 2>&1; then
    fail "Docker daemon is not reachable. Start Docker Desktop and retry."
  fi
}

wait_for_container() {
  local name="$1"
  local timeout="${2:-180}"
  local start
  start=$(date +%s)

  while true; do
    if ! docker inspect "$name" >/dev/null 2>&1; then
      sleep 2
      continue
    fi

    local inspect
    inspect=$(docker inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name")
    local status=${inspect%% *}
    local health=${inspect#* }

    if [[ "$status" == "running" ]]; then
      if [[ "$health" == "none" || "$health" == "healthy" ]]; then
        log "Container $name is ready (status=$status health=$health)"
        break
      fi
    fi

    if (( $(date +%s) - start > timeout )); then
      fail "Timed out waiting for $name (status=$status health=$health)"
    fi

    sleep 5
  done
}

ensure_kafka_topic() {
  local topic="$1"
  local partitions="${2:-3}"
  log "Ensuring Kafka topic '$topic' exists"
  "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" exec -T kafka \
    kafka-topics --bootstrap-server kafka:29092 \
    --create --topic "$topic" --partitions "$partitions" --replication-factor 1 --if-not-exists >/dev/null
}

seed_user_profiles() {
  log "Seeding Redis with demo user profiles"
  "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" exec -T user-profile-service node dist/seed_redis.js >/dev/null
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET_STACK=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
  shift
done

require_file "$COMPOSE_FILE"
require_command docker
check_wsl
detect_compose
ensure_docker_engine

if [[ -f "$ENV_HINT_FILE" ]]; then
  log "Loading optional overrides from $ENV_HINT_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_HINT_FILE"
  set +a
fi

if [[ $RESET_STACK -eq 1 ]]; then
  log "Resetting existing deployment (docker compose down -v)"
  "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" down -v --remove-orphans
fi

if [[ $SKIP_BUILD -eq 0 ]]; then
  log "Building Docker images"
  "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" build
else
  log "Skipping image build (reuse cached images)"
fi

log "Starting containers"
"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" up -d --remove-orphans

log "Waiting for core infrastructure"
wait_for_container helios-postgres 180
wait_for_container helios-redis 120
wait_for_container helios-zookeeper 120 || true
wait_for_container helios-kafka 180

log "Waiting for application services"
wait_for_container helios-user-profile 180
wait_for_container helios-bid-handler 180
wait_for_container helios-analytics-api 240
wait_for_container helios-dashboard 240

# Services without health checks: ensure they are running
for service in helios-bidding-logic helios-auction-simulator helios-analytics-consumer; do
  if ! docker inspect "$service" >/dev/null 2>&1; then
    fail "Container $service not found after startup"
  fi
  status_value=$(docker inspect --format '{{.State.Status}}' "$service")
  if [[ "$status_value" != "running" ]]; then
    fail "Container $service not running (status=$status_value)"
  fi
  log "Container $service is running"
done

log "Bootstrapping Kafka topics"
ensure_kafka_topic bid_requests 3
ensure_kafka_topic bid_responses 3
ensure_kafka_topic auction_outcomes 3

wait_for_container helios-user-profile 60
seed_user_profiles

log "Setup complete"
"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps

cat <<'EOF'
---------------------------------------------------------------------
Helios RTB Engine services are online.

HTTP entrypoint:       http://localhost:8080/bid
Analytics API:         http://localhost:8000/api/outcomes/
Advertiser dashboard:  http://localhost:3000
Kafka bootstrap:       localhost:9092

Next steps:
  1. Run the verification guide: TEST_AND_VERIFY.md
  2. Send sample bid requests and inspect analytics outputs.
---------------------------------------------------------------------
EOF
