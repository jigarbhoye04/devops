#!/bin/bash

# Helios RTB Engine - Load Generation Script
# Generates bid requests for testing and performance evaluation

set -e

# Default values
GATEWAY_URL=${1:-http://localhost:30080}
NUM_REQUESTS=${2:-100}
DELAY=${3:-0.1}

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Sample data arrays
USER_IDS=(
    "user-1" "user-2" "user-3" "user-4" "user-5"
    "user-6" "user-7" "user-8" "user-9" "user-10"
    "user-11" "user-12" "user-13" "user-14" "user-15"
    "user-16" "user-17" "user-18" "user-19" "user-20"
)

DOMAINS=(
    "example.com"
    "news.com"
    "sports.com"
    "tech.com"
    "finance.com"
    "travel.com"
    "shopping.com"
    "entertainment.com"
)

DEVICE_TYPES=(
    "mobile"
    "desktop"
    "tablet"
)

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Helios RTB Engine - Load Generator                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Gateway URL:      $GATEWAY_URL"
echo "  Total Requests:   $NUM_REQUESTS"
echo "  Delay (seconds):  $DELAY"
echo ""
echo -e "${YELLOW}Starting load generation...${NC}"
echo ""

# Counters
SUCCESS_COUNT=0
ERROR_COUNT=0
START_TIME=$(date +%s)

# Function to generate UUID (portable version)
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$RANDOM-$RANDOM"
    fi
}

# Function to get random element from array
get_random() {
    local arr=("$@")
    local rand_index=$(( RANDOM % ${#arr[@]} ))
    echo "${arr[$rand_index]}"
}

# Send requests
for i in $(seq 1 $NUM_REQUESTS); do
    # Generate random request data
    REQUEST_ID="req-$(generate_uuid)"
    USER_ID=$(get_random "${USER_IDS[@]}")
    SITE_DOMAIN=$(get_random "${DOMAINS[@]}")
    DEVICE_TYPE=$(get_random "${DEVICE_TYPES[@]}")
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create JSON payload
    PAYLOAD=$(cat <<EOF
{
  "request_id": "$REQUEST_ID",
  "user_id": "$USER_ID",
  "site_domain": "$SITE_DOMAIN",
  "device_type": "$DEVICE_TYPE",
  "timestamp": "$TIMESTAMP"
}
EOF
)

    # Send request
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY_URL/bid" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")
    
    # Check response
    if [ "$HTTP_CODE" -eq 202 ] || [ "$HTTP_CODE" -eq 200 ]; then
        ((SUCCESS_COUNT++))
    else
        ((ERROR_COUNT++))
        echo -e "${YELLOW}[Warning]${NC} Request $i failed with HTTP $HTTP_CODE"
    fi
    
    # Progress indicator
    if [ $((i % 50)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        RATE=$(echo "scale=2; $i / $ELAPSED" | bc -l 2>/dev/null || echo "N/A")
        echo -e "${GREEN}Progress:${NC} $i/$NUM_REQUESTS requests sent ($RATE req/s)"
    fi
    
    # Delay between requests
    sleep $DELAY
done

# Calculate statistics
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
SUCCESS_RATE=$(echo "scale=2; $SUCCESS_COUNT * 100 / $NUM_REQUESTS" | bc -l 2>/dev/null || echo "N/A")
AVG_RATE=$(echo "scale=2; $NUM_REQUESTS / $TOTAL_TIME" | bc -l 2>/dev/null || echo "N/A")

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 Load Generation Complete                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Statistics:${NC}"
echo "  Total Requests:    $NUM_REQUESTS"
echo "  Successful:        $SUCCESS_COUNT"
echo "  Failed:            $ERROR_COUNT"
echo "  Success Rate:      ${SUCCESS_RATE}%"
echo "  Total Time:        ${TOTAL_TIME}s"
echo "  Average Rate:      ${AVG_RATE} req/s"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  • View metrics in Grafana: $GATEWAY_URL/grafana"
echo "  • Check Analytics API: $GATEWAY_URL/api/outcomes/stats/"
echo "  • View Dashboard: $GATEWAY_URL/"
echo ""

# Wait for data to propagate
echo -e "${YELLOW}Waiting 10 seconds for data to propagate through pipeline...${NC}"
sleep 10

# Try to fetch stats
echo ""
echo "Fetching current analytics statistics..."
curl -s "$GATEWAY_URL/api/outcomes/stats/" | jq '.' 2>/dev/null || {
    echo "Unable to fetch statistics (may need to wait longer for data processing)"
}

echo ""
echo -e "${GREEN}Load generation complete!${NC}"
