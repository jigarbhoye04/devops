# Auction Simulator Service

## Overview

The Auction Simulator Service is a Node.js application that simulates the auction process in the Helios RTB Engine. It consumes bid responses from the `bid_responses` Kafka topic, runs auction logic to determine winners, and produces auction outcomes to the `auction_outcomes` Kafka topic.

## Features

- **Kafka Consumer**: Consumes bid response messages from the `bid_responses` topic
- **Auction Logic**: Determines auction winners based on configurable criteria:
  - Minimum bid threshold (default: $0.50)
  - Win probability (default: 70% for bids above threshold)
- **Kafka Producer**: Publishes auction outcomes to the `auction_outcomes` topic
- **Structured Logging**: All logs are output as JSON for easy parsing by log aggregators
- **Graceful Shutdown**: Handles SIGINT and SIGTERM signals properly

## Architecture

```
bid_responses (Kafka Topic)
        ↓
[Auction Simulator Service]
        ↓
auction_outcomes (Kafka Topic)
```

## Environment Variables

### Required
- `KAFKA_BROKER`: Kafka broker address(es), comma-separated (e.g., `kafka:9092`)
- `KAFKA_BID_RESPONSE_TOPIC`: Topic to consume bid responses from (default: `bid_responses`)
- `KAFKA_AUCTION_OUTCOME_TOPIC`: Topic to produce auction outcomes to (default: `auction_outcomes`)

### Optional
- `KAFKA_CONSUMER_GROUP`: Consumer group ID (default: `auction-simulator-group`)
- `MIN_BID_THRESHOLD`: Minimum bid price to be eligible for winning (default: `0.5`)
- `WIN_PROBABILITY`: Probability of winning for eligible bids (default: `0.7` = 70%)

## Message Formats

### Input: Bid Response Message
```json
{
  "bid_request_id": "req-12345",
  "user_id": "user-67890",
  "bid_price": 0.75,
  "currency": "USD",
  "timestamp": "2025-10-25T12:00:00.000Z",
  "enriched": true,
  "user_interests": ["technology", "sports"]
}
```

### Output: Auction Outcome Message
```json
{
  "bid_request_id": "req-12345",
  "user_id": "user-67890",
  "bid_price": 0.75,
  "currency": "USD",
  "timestamp": "2025-10-25T12:00:00.000Z",
  "enriched": true,
  "user_interests": ["technology", "sports"],
  "win_status": true,
  "win_price": 0.75,
  "auction_timestamp": "2025-10-25T12:00:01.000Z"
}
```

## Auction Logic

The service implements a simple first-price auction simulation:

1. **Validation**: Check if bid has a valid price
2. **Threshold Check**: Bid price must exceed `MIN_BID_THRESHOLD`
3. **Random Selection**: Eligible bids have a `WIN_PROBABILITY` chance of winning
4. **Win Price**: Winner pays their bid price (first-price auction)

## Local Development

### Prerequisites
- Node.js 20+
- Kafka broker running

### Setup
```bash
cd services/auction-simulator
npm install
```

### Run
```bash
# Set environment variables
export KAFKA_BROKER=localhost:9092
export KAFKA_BID_RESPONSE_TOPIC=bid_responses
export KAFKA_AUCTION_OUTCOME_TOPIC=auction_outcomes

# Start the service
npm start
```

## Docker

### Build
```bash
docker build -t helios/auction-simulator:latest .
```

### Run
```bash
docker run -e KAFKA_BROKER=kafka:9092 \
  -e KAFKA_BID_RESPONSE_TOPIC=bid_responses \
  -e KAFKA_AUCTION_OUTCOME_TOPIC=auction_outcomes \
  helios/auction-simulator:latest
```

## Kubernetes Deployment

The service is deployed as part of the Helios RTB Engine. See `kubernetes/services/05-auction-simulator/` for deployment manifests.

```bash
kubectl apply -f kubernetes/services/05-auction-simulator/
```

## Monitoring

All logs are structured JSON with the following fields:
- `timestamp`: ISO 8601 timestamp
- `level`: Log level (info, warning, error, fatal)
- `message`: Log message
- Additional context fields as needed

Example log entry:
```json
{
  "timestamp": "2025-10-25T12:00:00.000Z",
  "level": "info",
  "message": "Auction outcome published",
  "topic": "auction_outcomes",
  "bid_request_id": "req-12345",
  "win_status": true,
  "win_price": 0.75
}
```

## Testing

To test the auction service, you can:

1. Produce test bid responses to the `bid_responses` topic
2. Monitor the `auction_outcomes` topic for results
3. Check logs for detailed processing information

Example test bid response:
```bash
kafka-console-producer --broker-list localhost:9092 --topic bid_responses
{"bid_request_id":"test-123","user_id":"user-456","bid_price":0.85,"currency":"USD","timestamp":"2025-10-25T12:00:00.000Z"}
```

## Configuration Tuning

- **MIN_BID_THRESHOLD**: Adjust to set the minimum viable bid price
- **WIN_PROBABILITY**: Tune to control auction competitiveness (higher = more winners)
- **KAFKA_CONSUMER_GROUP**: Use different groups for multiple instances

## Phase 3 Integration

This service is part of Phase 3 of the Helios RTB Engine development:

**Data Flow:**
1. Bid Request Handler → `bid_requests` topic
2. Bidding Logic Service → `bid_responses` topic (generates bids)
3. **Auction Simulator** → `auction_outcomes` topic (determines winners)
4. Analytics Service → Consumes `auction_outcomes` for analysis

## License

Part of the Helios RTB Engine project.
