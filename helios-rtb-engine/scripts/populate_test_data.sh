#!/bin/bash

# Script to populate the Helios RTB database with realistic test data
# This sends multiple bid requests through the pipeline to generate outcomes

set -e

NAMESPACE="helios"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

# Configuration
NUM_REQUESTS=${1:-50}  # Default to 50 requests, or use first argument

print_header "Helios RTB Test Data Population"
print_info "Generating $NUM_REQUESTS bid requests..."
echo ""

# Arrays for test data variation
USER_IDS=("user-001" "user-002" "user-003" "user-004" "user-005" "user-006" "user-007" "user-008" "user-009" "user-010")
DEVICE_TYPES=("mobile" "desktop" "tablet" "mobile" "desktop")  # Mobile weighted more
DOMAINS=("techcrunch.com" "example.com" "news.com" "sports.net" "gaming.io" "finance.com" "travel.org")
PAGE_URLS=(
    "https://techcrunch.com/tech-news"
    "https://example.com/articles/latest"
    "https://news.com/breaking"
    "https://sports.net/scores"
    "https://gaming.io/reviews"
    "https://finance.com/markets"
    "https://travel.org/destinations"
)

# Function to get random element from array
get_random() {
    local arr=("$@")
    local size=${#arr[@]}
    local index=$((RANDOM % size))
    echo "${arr[$index]}"
}

# Send requests
SUCCESS_COUNT=0
FAIL_COUNT=0

for i in $(seq 1 $NUM_REQUESTS); do
    # Generate test data
    REQUEST_ID="load-test-$(date +%s)-$(printf %04d $i)"
    USER_ID=$(get_random "${USER_IDS[@]}")
    DEVICE_TYPE=$(get_random "${DEVICE_TYPES[@]}")
    DOMAIN=$(get_random "${DOMAINS[@]}")
    PAGE_URL=$(get_random "${PAGE_URLS[@]}")
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create JSON request
    REQUEST="{\"request_id\":\"$REQUEST_ID\",\"user_id\":\"$USER_ID\",\"timestamp\":\"$TIMESTAMP\",\"device_type\":\"$DEVICE_TYPE\",\"page_url\":\"$PAGE_URL\",\"site_domain\":\"$DOMAIN\"}"
    
    # Send to Kafka
    if echo "$REQUEST" | kubectl run kafka-producer-$i --rm -i --restart=Never \
        --image=confluentinc/cp-kafka:latest -n $NAMESPACE -- \
        kafka-console-producer \
        --bootstrap-server kafka.helios.svc.cluster.local:9092 \
        --topic bid_requests 2>/dev/null; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo -ne "\r${GREEN}✓${NC} Sent $SUCCESS_COUNT/$NUM_REQUESTS requests..."
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -ne "\r${YELLOW}⚠${NC} Sent $SUCCESS_COUNT/$NUM_REQUESTS requests ($FAIL_COUNT failed)..."
    fi
    
    # Small delay to avoid overwhelming the system
    sleep 0.2
done

echo ""
echo ""
print_success "Completed sending $SUCCESS_COUNT requests"

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} $FAIL_COUNT requests failed to send"
fi

# Wait for processing
print_info "Waiting 15 seconds for pipeline to process all requests..."
sleep 15

# Query database for results
print_header "Database Statistics"

POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l component=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$POSTGRES_POD" ]; then
    # Total outcomes
    TOTAL=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT COUNT(*) FROM outcomes_auctionoutcome;" 2>/dev/null | tr -d '[:space:]')
    
    # Win/Loss stats
    WINS=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT COUNT(*) FROM outcomes_auctionoutcome WHERE win_status = true;" 2>/dev/null | tr -d '[:space:]')
    
    LOSSES=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT COUNT(*) FROM outcomes_auctionoutcome WHERE win_status = false;" 2>/dev/null | tr -d '[:space:]')
    
    # Revenue stats
    TOTAL_REVENUE=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT ROUND(SUM(win_price)::numeric, 2) FROM outcomes_auctionoutcome WHERE win_status = true;" 2>/dev/null | tr -d '[:space:]')
    
    AVG_WIN_PRICE=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT ROUND(AVG(win_price)::numeric, 4) FROM outcomes_auctionoutcome WHERE win_status = true;" 2>/dev/null | tr -d '[:space:]')
    
    AVG_BID_PRICE=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT ROUND(AVG(bid_price)::numeric, 4) FROM outcomes_auctionoutcome;" 2>/dev/null | tr -d '[:space:]')
    
    ENRICHED=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT COUNT(*) FROM outcomes_auctionoutcome WHERE enriched = true;" 2>/dev/null | tr -d '[:space:]')
    
    echo ""
    print_info "Total Outcomes in Database: $TOTAL"
    print_info "Wins: $WINS"
    print_info "Losses: $LOSSES"
    
    if [ "$TOTAL" -gt 0 ]; then
        WIN_RATE=$(awk "BEGIN {printf \"%.2f\", ($WINS * 100 / $TOTAL)}")
        print_info "Win Rate: ${WIN_RATE}%"
    fi
    
    if [ "$WINS" -gt 0 ]; then
        print_info "Total Revenue: \$$TOTAL_REVENUE"
        print_info "Average Win Price: \$$AVG_WIN_PRICE"
    fi
    
    print_info "Average Bid Price: \$$AVG_BID_PRICE"
    print_info "Enriched with User Profile: $ENRICHED"
    
    echo ""
    print_header "Sample Outcomes"
    kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -c \
        "SELECT 
            bid_id, 
            user_id, 
            site_domain,
            device_type,
            win_status, 
            ROUND(win_price::numeric, 2) as win_price,
            ROUND(bid_price::numeric, 2) as bid_price,
            enriched,
            TO_CHAR(timestamp, 'HH24:MI:SS') as time
         FROM outcomes_auctionoutcome 
         ORDER BY timestamp DESC 
         LIMIT 15;" 2>/dev/null
    
    echo ""
    print_header "Win/Loss by User"
    kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -c \
        "SELECT 
            user_id,
            COUNT(*) as total_bids,
            SUM(CASE WHEN win_status THEN 1 ELSE 0 END) as wins,
            SUM(CASE WHEN NOT win_status THEN 1 ELSE 0 END) as losses,
            ROUND(AVG(CASE WHEN win_status THEN win_price ELSE 0 END)::numeric, 2) as avg_win_price
         FROM outcomes_auctionoutcome 
         GROUP BY user_id
         ORDER BY total_bids DESC;" 2>/dev/null
    
    echo ""
    print_header "Win/Loss by Device Type"
    kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -c \
        "SELECT 
            device_type,
            COUNT(*) as total_bids,
            SUM(CASE WHEN win_status THEN 1 ELSE 0 END) as wins,
            ROUND((SUM(CASE WHEN win_status THEN 1 ELSE 0 END)::numeric / COUNT(*)::numeric * 100), 2) as win_rate_pct
         FROM outcomes_auctionoutcome 
         GROUP BY device_type
         ORDER BY total_bids DESC;" 2>/dev/null
    
    echo ""
    print_header "Win/Loss by Domain"
    kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -c \
        "SELECT 
            site_domain,
            COUNT(*) as total_bids,
            SUM(CASE WHEN win_status THEN 1 ELSE 0 END) as wins,
            ROUND(SUM(CASE WHEN win_status THEN win_price ELSE 0 END)::numeric, 2) as total_revenue
         FROM outcomes_auctionoutcome 
         GROUP BY site_domain
         ORDER BY total_bids DESC;" 2>/dev/null
else
    echo -e "${YELLOW}⚠${NC} PostgreSQL pod not found"
fi

echo ""
print_header "Test Data Population Complete"
print_success "You can now access the analytics API to view the data"
echo ""
print_info "View API data:"
echo "  kubectl port-forward -n helios svc/analytics-service 8000:8000"
echo "  curl http://localhost:8000/api/outcomes/stats/ | jq"
echo ""
print_info "Monitor consumer logs:"
echo "  kubectl logs -n helios -l role=consumer -f"
echo ""
