#!/usr/bin/env bash
# Lightweight readiness probe for the Helios RTB Engine stack.
# Ensures critical containers and HTTP endpoints are healthy before Postman automation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
COMPOSE_FILE="$REPO_ROOT/helios-rtb-engine/docker-compose.full.yml"

require_file() {
  local path="$1"
  [[ -f "$path" ]] || {
    printf '[pre-check][error] Required file not found: %s\n' "$path" >&2
    exit 1
  }
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    printf '[pre-check][error] Missing command: %s\n' "$cmd" >&2
    exit 1
  }
}

log() {
  printf '[pre-check] %s\n' "$*"
}

section() {
  printf '\n=== %s ===\n' "$*"
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
  elif docker-compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
  else
    printf '[pre-check][error] Docker Compose CLI not found.\n' >&2
    exit 1
  fi
}

check_container() {
  local name="$1"
  local label="$2"
  if ! docker inspect "$name" >/dev/null 2>&1; then
    printf '[pre-check][error] Container %s (%s) not found.\n' "$name" "$label" >&2
    exit 1
  fi
  local inspect
  inspect=$(docker inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name")
  local status=${inspect%% *}
  local health=${inspect#* }
  if [[ "$status" != "running" ]]; then
    printf '[pre-check][error] Container %s (%s) status=%s health=%s\n' "$name" "$label" "$status" "$health" >&2
    exit 1
  fi
  if [[ "$health" != "none" && "$health" != "healthy" ]]; then
    printf '[pre-check][error] Container %s (%s) health=%s\n' "$name" "$label" "$health" >&2
    exit 1
  fi
  printf '[pre-check] %s (%s) OK (status=%s health=%s)\n' "$name" "$label" "$status" "$health"
}

probe_http() {
  local url="$1"
  local name="$2"
  if ! curl -fsS --max-time 5 "$url" >/dev/null; then
    printf '[pre-check][error] HTTP probe failed: %s (%s)\n' "$url" "$name" >&2
    exit 1
  fi
  printf '[pre-check] HTTP probe success: %s (%s)\n' "$url" "$name"
}

probe_text_contains() {
  local url="$1"
  local name="$2"
  local expected="$3"
  local body
  if ! body=$(curl -fsS --max-time 5 "$url"); then
    printf '[pre-check][error] HTTP fetch failed: %s (%s)\n' "$url" "$name" >&2
    exit 1
  fi
  if [[ "$body" != *"$expected"* ]]; then
    printf '[pre-check][error] Expected token "%s" not found in %s (%s)\n' "$expected" "$url" "$name" >&2
    exit 1
  fi
  printf '[pre-check] Content OK: %s contains "%s"\n' "$name" "$expected"
}

probe_kafka() {
  if ! "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" exec -T kafka \
        kafka-broker-api-versions --bootstrap-server kafka:29092 >/dev/null 2>&1; then
    printf '[pre-check][error] Kafka broker probe failed.\n' >&2
    exit 1
  fi
  printf '[pre-check] Kafka broker probe OK.\n'
}

require_file "$COMPOSE_FILE"
require_command docker
require_command curl
detect_compose

section "Container Health"
# Containers with explicit health checks first
check_container helios-postgres "PostgreSQL"
check_container helios-redis "Redis"
check_container helios-user-profile "User Profile Service"
check_container helios-analytics-api "Analytics API"
check_container helios-dashboard "Advertiser Dashboard"
check_container helios-bid-handler "Bid Request Handler"

# Containers without native health checks (status only)
check_container helios-bidding-logic "Bidding Logic Service"
check_container helios-auction-simulator "Auction Simulator"
check_container helios-analytics-consumer "Analytics Consumer"
check_container helios-kafka "Kafka"
check_container helios-zookeeper "Zookeeper"

section "HTTP Endpoint Probes"
probe_http "http://localhost:8080/healthz" "Bid Handler Health"
probe_http "http://localhost:2112/metrics" "Bid Handler Metrics"
probe_http "http://localhost:8000/api/outcomes/" "Analytics API"
probe_http "http://localhost:3000/api/health" "Advertiser Dashboard"
probe_http "http://localhost:8001/metrics" "Bidding Logic Metrics"

section "Kafka Connectivity"
probe_kafka

printf '\n[pre-check] All systems ready for Postman tests.\n'
