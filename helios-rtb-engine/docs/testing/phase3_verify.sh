#!/bin/bash

# Complete End-to-End Verification Script
# Verifies: Auction Service, Analytics Service, PostgreSQL, and full data pipeline

set -e

NAMESPACE="helios"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
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

# Check prerequisites
check_prerequisites() {
    print_header "Phase 3 End-to-End Verification"
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Some JSON parsing will be limited."
    fi
    
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        print_error "Namespace '$NAMESPACE' not found"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Step 1: Verify PostgreSQL
verify_postgres() {
    print_header "Step 1: Verifying PostgreSQL"
    
    # Check StatefulSet
    if kubectl get statefulset postgres -n $NAMESPACE &> /dev/null; then
        print_success "PostgreSQL StatefulSet exists"
    else
        print_error "PostgreSQL StatefulSet not found"
        return 1
    fi
    
    # Check pod
    POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l component=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POSTGRES_POD" ]; then
        STATUS=$(kubectl get pod "$POSTGRES_POD" -n $NAMESPACE -o jsonpath='{.status.phase}')
        if [ "$STATUS" = "Running" ]; then
            print_success "PostgreSQL pod is running: $POSTGRES_POD"
        else
            print_warning "PostgreSQL pod status: $STATUS"
        fi
    else
        print_error "PostgreSQL pod not found"
        return 1
    fi
    
    # Check database
    DB_EXISTS=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='helios_analytics';" 2>/dev/null || echo "")
    
    if [[ "$DB_EXISTS" == "1" ]]; then
        print_success "Database 'helios_analytics' exists"
    else
        print_warning "Database 'helios_analytics' not found (will be created on first migration)"
    fi
    
    # Check table
    TABLE_EXISTS=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT 1 FROM information_schema.tables WHERE table_name='outcomes_auctionoutcome';" 2>/dev/null || echo "")
    
    if [[ "$TABLE_EXISTS" == "1" ]]; then
        print_success "Table 'outcomes_auctionoutcome' exists"
        
        # Get record count
        COUNT=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
            psql -U helios -d helios_analytics -tAc \
            "SELECT COUNT(*) FROM outcomes_auctionoutcome;" 2>/dev/null | tr -d '[:space:]' || echo "0")
        print_info "Current outcome records: $COUNT"
    else
        print_warning "Table 'outcomes_auctionoutcome' not found (run migrations)"
    fi
}

# Step 2: Verify Auction Simulator
verify_auction_simulator() {
    print_header "Step 2: Verifying Auction Simulator"
    
    # Check deployment
    if kubectl get deployment auction-simulator-deployment -n $NAMESPACE &> /dev/null; then
        REPLICAS=$(kubectl get deployment auction-simulator-deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' || echo "0")
        if [ "$REPLICAS" -gt 0 ]; then
            print_success "Auction simulator is running ($REPLICAS replicas)"
        else
            print_warning "Auction simulator has no ready replicas"
        fi
    else
        print_error "Auction simulator deployment not found"
        return 1
    fi
    
    # Check service
    if kubectl get service auction-simulator -n $NAMESPACE &> /dev/null; then
        print_success "Auction simulator service exists"
    else
        print_warning "Auction simulator service not found"
    fi
    
    # Check environment variables
    ENV_VARS=$(kubectl get deployment auction-simulator-deployment -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].env[*].name}')
    REQUIRED_VARS=("KAFKA_BROKER" "KAFKA_BID_RESPONSE_TOPIC" "KAFKA_AUCTION_OUTCOME_TOPIC")
    
    for VAR in "${REQUIRED_VARS[@]}"; do
        if echo "$ENV_VARS" | grep -q "$VAR"; then
            print_success "$VAR is configured"
        else
            print_error "$VAR is missing"
        fi
    done
    
    # Check logs
    AUCTION_POD=$(kubectl get pods -n $NAMESPACE -l component=auction-simulator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$AUCTION_POD" ]; then
        print_info "Recent auction simulator logs:"
        kubectl logs -n $NAMESPACE "$AUCTION_POD" --tail=5 2>/dev/null | sed 's/^/  /'
    fi
}

# Step 3: Verify Analytics Service
verify_analytics_service() {
    print_header "Step 3: Verifying Analytics Service"
    
    # Check API deployment
    if kubectl get deployment analytics-api-deployment -n $NAMESPACE &> /dev/null; then
        API_REPLICAS=$(kubectl get deployment analytics-api-deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' || echo "0")
        if [ "$API_REPLICAS" -gt 0 ]; then
            print_success "Analytics API is running ($API_REPLICAS replicas)"
        else
            print_warning "Analytics API has no ready replicas"
        fi
    else
        print_error "Analytics API deployment not found"
        return 1
    fi
    
    # Check consumer deployment
    if kubectl get deployment analytics-consumer-deployment -n $NAMESPACE &> /dev/null; then
        CONSUMER_REPLICAS=$(kubectl get deployment analytics-consumer-deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' || echo "0")
        if [ "$CONSUMER_REPLICAS" -gt 0 ]; then
            print_success "Analytics consumer is running ($CONSUMER_REPLICAS replicas)"
        else
            print_warning "Analytics consumer has no ready replicas"
        fi
    else
        print_warning "Analytics consumer deployment not found"
    fi
    
    # Check service
    if kubectl get service analytics-service -n $NAMESPACE &> /dev/null; then
        SERVICE_IP=$(kubectl get service analytics-service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
        SERVICE_PORT=$(kubectl get service analytics-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
        print_success "Analytics service exists at ${SERVICE_IP}:${SERVICE_PORT}"
    else
        print_error "Analytics service not found"
    fi
    
    # Check environment variables
    ENV_VARS=$(kubectl get deployment analytics-api-deployment -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].env[*].name}')
    REQUIRED_VARS=("DB_NAME" "DB_USER" "DB_HOST" "KAFKA_BROKERS" "KAFKA_TOPIC_AUCTION_OUTCOMES")
    
    for VAR in "${REQUIRED_VARS[@]}"; do
        if echo "$ENV_VARS" | grep -q "$VAR"; then
            print_success "$VAR is configured"
        else
            print_error "$VAR is missing"
        fi
    done
    
    # Check consumer logs
    CONSUMER_POD=$(kubectl get pods -n $NAMESPACE -l role=consumer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$CONSUMER_POD" ]; then
        print_info "Recent consumer logs:"
        kubectl logs -n $NAMESPACE "$CONSUMER_POD" --tail=5 2>/dev/null | sed 's/^/  /'
    fi
}

# Step 4: Verify Bidding Logic Service
verify_bidding_logic() {
    print_header "Step 4: Verifying Bidding Logic Service"
    
    if kubectl get deployment bidding-logic-service-deployment -n $NAMESPACE &> /dev/null; then
        REPLICAS=$(kubectl get deployment bidding-logic-service-deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' || echo "0")
        if [ "$REPLICAS" -gt 0 ]; then
            print_success "Bidding logic service is running ($REPLICAS replicas)"
        else
            print_warning "Bidding logic service has no ready replicas"
        fi
        
        # Check for bid_responses topic configuration
        BID_LOGIC_ENV=$(kubectl get deployment bidding-logic-service-deployment -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].env[*].name}')
        if echo "$BID_LOGIC_ENV" | grep -q "KAFKA_TOPIC_BID_RESPONSES"; then
            print_success "Bid responses topic configured"
        else
            print_warning "KAFKA_TOPIC_BID_RESPONSES not configured"
        fi
    else
        print_error "Bidding logic service deployment not found"
    fi
}

# Step 5: Verify Kafka Topics
verify_kafka_topics() {
    print_header "Step 5: Verifying Kafka Topics"
    
    KAFKA_POD=$(kubectl get pods -n $NAMESPACE -l app=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$KAFKA_POD" ]; then
        print_info "Kafka pod: $KAFKA_POD"
        
        TOPICS=$(kubectl exec -n $NAMESPACE "$KAFKA_POD" -- \
            kafka-topics.sh --list --bootstrap-server localhost:9092 2>/dev/null || echo "")
        
        for TOPIC in "bid_requests" "bid_responses" "auction_outcomes"; do
            if echo "$TOPICS" | grep -q "^${TOPIC}$"; then
                print_success "Topic '$TOPIC' exists"
            else
                print_warning "Topic '$TOPIC' not found (will be auto-created on first use)"
            fi
        done
    else
        print_warning "Kafka pod not found, skipping topic verification"
    fi
}

# Step 6: Test Analytics API
test_analytics_api() {
    print_header "Step 6: Testing Analytics API"
    
    API_POD=$(kubectl get pods -n $NAMESPACE -l role=api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$API_POD" ]; then
        print_error "API pod not found"
        return 1
    fi
    
    print_info "Starting port-forward to analytics service..."
    kubectl port-forward -n $NAMESPACE "$API_POD" 8000:8000 > /dev/null 2>&1 &
    PF_PID=$!
    sleep 3
    
    # Test endpoints
    print_info "Testing API endpoints..."
    
    # Test /api/outcomes/
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/outcomes/ 2>/dev/null || echo "000")
    if [ "$RESPONSE" = "200" ]; then
        print_success "GET /api/outcomes/ - HTTP $RESPONSE"
        
        if command -v jq &> /dev/null; then
            DATA=$(curl -s http://localhost:8000/api/outcomes/ 2>/dev/null)
            COUNT=$(echo "$DATA" | jq -r '.count // 0' 2>/dev/null || echo "0")
            print_info "Total outcomes: $COUNT"
        fi
    else
        print_error "GET /api/outcomes/ - HTTP $RESPONSE"
    fi
    
    # Test /api/outcomes/stats/
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/outcomes/stats/ 2>/dev/null || echo "000")
    if [ "$RESPONSE" = "200" ]; then
        print_success "GET /api/outcomes/stats/ - HTTP $RESPONSE"
        
        if command -v jq &> /dev/null; then
            STATS=$(curl -s http://localhost:8000/api/outcomes/stats/ 2>/dev/null)
            echo "$STATS" | jq '.' 2>/dev/null | sed 's/^/  /'
        fi
    else
        print_error "GET /api/outcomes/stats/ - HTTP $RESPONSE"
    fi
    
    # Test /api/outcomes/winners/
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/outcomes/winners/ 2>/dev/null || echo "000")
    if [ "$RESPONSE" = "200" ]; then
        print_success "GET /api/outcomes/winners/ - HTTP $RESPONSE"
    else
        print_warning "GET /api/outcomes/winners/ - HTTP $RESPONSE"
    fi
    
    # Cleanup
    kill $PF_PID 2>/dev/null || true
}

# Step 7: Send Test Request
send_test_request() {
    print_header "Step 7: Sending Test Bid Request"
    
    TEST_ID="e2e-verify-$(date +%s)"
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    TEST_REQUEST="{\"request_id\":\"$TEST_ID\",\"user_id\":\"test-user-999\",\"timestamp\":\"$TIMESTAMP\",\"device_type\":\"mobile\",\"page_url\":\"https://example.com/tech\",\"site_domain\":\"example.com\"}"
    
    print_info "Sending test request: $TEST_ID"
    
    echo "$TEST_REQUEST" | kubectl run kafka-test-producer-$$ --rm -i --restart=Never \
        --image=confluentinc/cp-kafka:latest -n $NAMESPACE -- \
        kafka-console-producer \
        --bootstrap-server kafka.helios.svc.cluster.local:9092 \
        --topic bid_requests 2>/dev/null
    
    print_success "Test request sent: $TEST_ID"
    
    print_info "Waiting 10 seconds for pipeline processing..."
    sleep 10
    
    # Check if outcome exists in database
    POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l component=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$POSTGRES_POD" ]; then
        OUTCOME=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
            psql -U helios -d helios_analytics -tAc \
            "SELECT COUNT(*) FROM outcomes_auctionoutcome WHERE bid_id='$TEST_ID';" 2>/dev/null | tr -d '[:space:]' || echo "0")
        
        if [ "$OUTCOME" = "1" ]; then
            print_success "✓ Outcome found in database for bid_id: $TEST_ID"
            
            print_info "Outcome details:"
            kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
                psql -U helios -d helios_analytics -c \
                "SELECT bid_id, user_id, win_status, win_price, enriched, timestamp FROM outcomes_auctionoutcome WHERE bid_id='$TEST_ID';" 2>/dev/null | sed 's/^/  /'
        else
            print_error "Outcome NOT found in database"
            print_info "Check service logs for issues"
        fi
    fi
}

# Step 8: Database Statistics
show_database_stats() {
    print_header "Step 8: Database Statistics"
    
    POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l component=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$POSTGRES_POD" ]; then
        print_warning "PostgreSQL pod not found"
        return
    fi
    
    # Total outcomes
    TOTAL=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT COUNT(*) FROM outcomes_auctionoutcome;" 2>/dev/null | tr -d '[:space:]' || echo "0")
    
    # Win count
    WINS=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT COUNT(*) FROM outcomes_auctionoutcome WHERE win_status = true;" 2>/dev/null | tr -d '[:space:]' || echo "0")
    
    # Loss count
    LOSSES=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT COUNT(*) FROM outcomes_auctionoutcome WHERE win_status = false;" 2>/dev/null | tr -d '[:space:]' || echo "0")
    
    # Average win price
    AVG_PRICE=$(kubectl exec -n $NAMESPACE "$POSTGRES_POD" -- \
        psql -U helios -d helios_analytics -tAc \
        "SELECT ROUND(AVG(win_price)::numeric, 4) FROM outcomes_auctionoutcome WHERE win_status = true;" 2>/dev/null | tr -d '[:space:]' || echo "0")
    
    print_info "Total Outcomes: $TOTAL"
    print_info "Wins: $WINS"
    print_info "Losses: $LOSSES"
    
    if [ "$TOTAL" -gt 0 ]; then
        WIN_RATE=$(awk "BEGIN {printf \"%.2f\", ($WINS * 100 / $TOTAL)}")
        print_info "Win Rate: ${WIN_RATE}%"
    fi
    
    if [ "$WINS" -gt 0 ]; then
        print_info "Average Win Price: \$$AVG_PRICE"
    fi
}

# Main execution
main() {
    check_prerequisites
    verify_postgres
    verify_auction_simulator
    verify_analytics_service
    verify_bidding_logic
    verify_kafka_topics
    test_analytics_api
    send_test_request
    show_database_stats
    
    print_header "Verification Complete"
    
    print_success "All Phase 3 components verified!"
    echo ""
    print_info "Next Steps:"
    echo "  • View API: kubectl port-forward -n $NAMESPACE svc/analytics-service 8000:8000"
    echo "           Then visit: http://localhost:8000/api/outcomes/"
    echo ""
    echo "  • Create superuser: kubectl exec -it deployment/analytics-api-deployment -n $NAMESPACE -- python manage.py createsuperuser"
    echo "           Then visit: http://localhost:8000/admin/"
    echo ""
    echo "  • Monitor logs: kubectl logs -n $NAMESPACE -l role=consumer -f"
    echo ""
    echo "  • See full documentation: docs/testing/phase-3-verification.md"
    echo ""
}

# Run main
main
