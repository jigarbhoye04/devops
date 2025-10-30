#!/usr/bin/env bash
# Automated verification harness for the Helios RTB Engine Docker deployment.
# Usage: ./test.sh [--skip-postman]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
COMPOSE_FILE="$REPO_ROOT/helios-rtb-engine/docker-compose.full.yml"

SKIP_POSTMAN=0

usage() {
  cat <<'EOF'
Usage: ./test.sh [options]
  --skip-postman   Skip printing Postman collection instructions
  -h, --help       Show this help message
EOF
}

log() {
  printf '[test] %s\n' "$*"
}

section() {
  printf '\n===== %s =====\n' "$*"
}

fail() {
  printf '[test][error] %s\n' "$*" >&2
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

jq_available() {
  command -v jq >/dev/null 2>&1
}

pretty_print() {
  local payload="$1"
  if jq_available; then
    printf '%s\n' "$payload" | jq .
  else
    printf '%s\n' "$payload"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-postman)
      SKIP_POSTMAN=1
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
require_command curl
require_command mktemp
detect_compose

section "Container Health"
log "Checking container status"
"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps

section "Redis Seed Validation"
log "Fetching seeded user profiles"
"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" exec redis \
  redis-cli KEYS "user-*"

section "Bid Injection"
ENRICHED_PAYLOAD="$(mktemp /tmp/helios-bid-enriched.XXXXXX.json)"
FALLBACK_PAYLOAD="$(mktemp /tmp/helios-bid-fallback.XXXXXX.json)"
trap 'rm -f "$ENRICHED_PAYLOAD" "$FALLBACK_PAYLOAD"' EXIT

cat >"$ENRICHED_PAYLOAD" <<'JSON'
{
  "request_id": "demo-request-enriched",
  "user_id": "user-001",
  "site": {
    "domain": "news.example.com",
    "page": "https://news.example.com/home"
  },
  "device": {
    "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    "ip": "192.0.2.10"
  },
  "ad_slots": [
    {
      "id": "slot-1",
      "min_bid": 0.35,
      "format": ["300x250"]
    }
  ]
}
JSON

cat >"$FALLBACK_PAYLOAD" <<'JSON'
{
  "request_id": "demo-request-fallback",
  "user_id": "user-anonymous",
  "site": {
    "domain": "travel.example.com",
    "page": "https://travel.example.com/top-destinations"
  },
  "device": {
    "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    "ip": "198.51.100.48"
  },
  "ad_slots": [
    {
      "id": "slot-7",
      "min_bid": 0.30,
      "format": ["728x90"]
    }
  ]
}
JSON

log "Submitting enriched bid"
curl -s -o /tmp/helios-response-enriched.txt -w 'HTTP %{response_code}\n' \
  -H "Content-Type: application/json" \
  --data @"$ENRICHED_PAYLOAD" \
  http://localhost:8080/bid

log "Submitting fallback bid"
curl -s -o /tmp/helios-response-fallback.txt -w 'HTTP %{response_code}\n' \
  -H "Content-Type: application/json" \
  --data @"$FALLBACK_PAYLOAD" \
  http://localhost:8080/bid

section "Bid Handler Metrics"
log "Inspecting prom metrics for bid intake"
curl -s http://localhost:2112/metrics | grep -E 'bid_requests_total'

section "Kafka Topics"
log "Fetching last bid response"
"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" exec -T kafka \
  kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic bid_responses \
    --from-beginning \
    --max-messages 2 \
    --timeout-ms 2000

log "Fetching last auction outcome"
"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" exec -T kafka \
  kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic auction_outcomes \
    --from-beginning \
    --max-messages 2 \
    --timeout-ms 2000

section "Analytics Persistence"
log "Querying latest outcomes in PostgreSQL"
"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" exec postgres \
  psql -X -U helios -d helios_analytics \
  -c "SELECT bid_id, user_id, win_status, win_price, created_at FROM outcomes_auctionoutcome ORDER BY created_at DESC LIMIT 5;"

log "Calling analytics API"
ANALYTICS_RAW=$(curl -s http://localhost:8000/api/outcomes/?page_size=5)
if jq_available; then
  printf '%s\n' "$ANALYTICS_RAW" | jq '[.results[] | {bid_request_id: .bid_request_id, user_id: .user_id, win_status: .win_status, win_price: .win_price}]'
else
  printf '%s\n' "$ANALYTICS_RAW"
  log "Consider installing jq for prettified output"
fi

section "Analytics Deep Dive"
log "Filtering outcomes for user user-001"
USER_FILTER=$(curl -s "http://localhost:8000/api/outcomes/?user_id=user-001&page_size=5")
if jq_available; then
  printf '%s\n' "$USER_FILTER" | jq '[.results[] | {bid_request_id: .bid_request_id, user_id: .user_id, win_status: .win_status, win_price: .win_price}]'
else
  printf '%s\n' "$USER_FILTER"
fi

log "Filtering winning outcomes"
WIN_FILTER=$(curl -s "http://localhost:8000/api/outcomes/?win_status=true&page_size=5")
if jq_available; then
  printf '%s\n' "$WIN_FILTER" | jq '[.results[] | {bid_request_id: .bid_request_id, win_status: .win_status, win_price: .win_price}]'
else
  printf '%s\n' "$WIN_FILTER"
fi

log "Filtering outcomes within price band 0.30 - 1.00"
PRICE_FILTER=$(curl -s "http://localhost:8000/api/outcomes/?min_price=0.30&max_price=1.00&page_size=5")
if jq_available; then
  printf '%s\n' "$PRICE_FILTER" | jq '[.results[] | {bid_request_id: .bid_request_id, win_price: .win_price}]'
else
  printf '%s\n' "$PRICE_FILTER"
fi

log "Aggregated statistics"
STATS_PAYLOAD=$(curl -s http://localhost:8000/api/outcomes/stats/)
pretty_print "$STATS_PAYLOAD"

log "Winning outcomes (dedicated endpoint)"
WINNERS_PAYLOAD=$(curl -s http://localhost:8000/api/outcomes/winners/)
pretty_print "$WINNERS_PAYLOAD"

log "Daily stats"
DAILY_PAYLOAD=$(curl -s http://localhost:8000/api/outcomes/daily_stats/)
pretty_print "$DAILY_PAYLOAD"

section "User Profile gRPC Probe"
"${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" exec user-profile-service node - <<'NODE'
const path = require('node:path');
const protoLoader = require('@grpc/proto-loader');
const grpc = require('@grpc/grpc-js');

const PROTO_PATH = process.env.PROTO_PATH || path.join(process.cwd(), 'proto', 'user_profile.proto');
const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: false,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true
});

const helios = grpc.loadPackageDefinition(packageDefinition).helios;
const client = new helios.userprofile.UserProfileService('127.0.0.1:50051', grpc.credentials.createInsecure());

const requests = [
  { label: 'known user', payload: { userId: 'user-001' } },
  { label: 'anonymous user', payload: { userId: 'user-anonymous' } }
];

let pending = requests.length;
let exitCode = 0;

requests.forEach(({ label, payload }) => {
  client.getUserProfile(payload, (err, response) => {
    if (err) {
      console.error(`[grpc] ${label} error: ${err.message}`);
      exitCode = 1;
    } else {
      console.log(`[grpc] ${label} response: ${JSON.stringify(response)}`);
    }
    if (--pending === 0) {
      process.exit(exitCode);
    }
  });
});

setTimeout(() => {
  console.error('[grpc] timeout waiting for responses');
  process.exit(1);
}, 5000);
NODE

if [[ $SKIP_POSTMAN -eq 0 ]]; then
  section "Postman Collection"
  log "Import postman/helios-rtb-smoke.postman_collection.json for the comprehensive REST + gRPC suite."
  log "Tip: after importing, update the collection variable proto_path to point at your local proto/user_profile.proto so the gRPC request can bind the contract."
fi

section "Dashboard Check"
log "Verify the dashboard at http://localhost:3000"

log "Test suite completed"
