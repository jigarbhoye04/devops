# Analytics Service

## Overview

The Analytics Service is a Django-based application that consumes auction outcomes from Kafka and provides a REST API for querying and analyzing RTB auction results. It persists auction data to PostgreSQL for long-term storage and analysis.

## Architecture

```
auction_outcomes (Kafka Topic)
        ↓
[Kafka Consumer] → [PostgreSQL Database]
        ↓
[Django REST API] → /api/outcomes/
```

## Features

- **Kafka Consumer**: Background process that consumes auction outcomes from Kafka
- **PostgreSQL Storage**: Persistent storage for auction data with optimized indexes
- **REST API**: Full-featured API for querying auction outcomes
- **Data Aggregation**: Built-in endpoints for statistics and analytics
- **Admin Interface**: Django admin for data inspection
- **Structured Logging**: JSON-formatted logs for easy aggregation

## Components

### 1. Django Model: AuctionOutcome

Stores complete auction outcome data with the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `id` | BigInt | Auto-incrementing primary key |
| `bid_id` | String | Unique bid request identifier |
| `user_id` | String | User identifier |
| `site_domain` | String | Site domain (optional) |
| `win_status` | Boolean | Whether bid won auction |
| `win_price` | Decimal | Final auction win price |
| `bid_price` | Decimal | Original bid price |
| `currency` | String | Currency code (ISO 4217) |
| `enriched` | Boolean | Whether bid was enriched |
| `timestamp` | DateTime | When auction occurred |
| `auction_timestamp` | DateTime | Auction processing time |
| `user_interests` | JSON | User interests array |
| `raw_data` | JSON | Complete raw data from Kafka |
| `created_at` | DateTime | Record creation time |
| `updated_at` | DateTime | Last update time |

### 2. Management Command: process_outcomes

Background Kafka consumer that:
- Connects to the `auction_outcomes` Kafka topic
- Deserializes JSON messages
- Creates `AuctionOutcome` records in PostgreSQL
- Handles errors gracefully with structured logging

### 3. REST API Endpoints

#### List/Retrieve Outcomes
- `GET /api/outcomes/` - List all outcomes (paginated)
- `GET /api/outcomes/{id}/` - Retrieve specific outcome

#### Filtered Queries
Query parameters:
- `user_id` - Filter by user
- `site_domain` - Filter by domain
- `win_status` - Filter by win/loss (true/false)
- `enriched` - Filter by enrichment status
- `min_price` - Minimum win price
- `max_price` - Maximum win price
- `ordering` - Order by field (e.g., `-timestamp`, `win_price`)

#### Statistics Endpoints
- `GET /api/outcomes/stats/` - Aggregated statistics
- `GET /api/outcomes/winners/` - Only winning outcomes
- `GET /api/outcomes/daily_stats/` - Daily aggregated data

## Environment Variables

### Required
- `DB_NAME` - PostgreSQL database name (default: `helios_analytics`)
- `DB_USER` - Database user (default: `postgres`)
- `DB_PASSWORD` - Database password
- `DB_HOST` - Database host (default: `localhost`)
- `DB_PORT` - Database port (default: `5432`)
- `KAFKA_BROKERS` - Kafka broker addresses (default: `localhost:9092`)
- `KAFKA_TOPIC_AUCTION_OUTCOMES` - Input topic (default: `auction_outcomes`)

### Optional
- `DJANGO_SECRET_KEY` - Django secret key (required for production)
- `DEBUG` - Debug mode (default: `False`)
- `ALLOWED_HOSTS` - Allowed hosts (default: `*`)
- `KAFKA_CONSUMER_GROUP` - Consumer group ID (default: `analytics-service-group`)
- `LOG_LEVEL` - Logging level (default: `INFO`)

## Local Development

### Prerequisites
- Python 3.12+
- PostgreSQL 14+
- Kafka broker

### Setup

```bash
cd services/analytics-service

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export DB_NAME=helios_analytics
export DB_USER=postgres
export DB_PASSWORD=yourpassword
export DB_HOST=localhost
export DB_PORT=5432
export KAFKA_BROKERS=localhost:9092
export DJANGO_SECRET_KEY=your-secret-key

# Run migrations
python manage.py migrate

# Create superuser (optional)
python manage.py createsuperuser

# Start API server
python manage.py runserver 0.0.0.0:8000

# In another terminal, start Kafka consumer
python manage.py process_outcomes
```

### Run Tests

```bash
python manage.py test
```

## Docker

### Build

```bash
docker build -t helios/analytics-service:phase3 .
```

### Run API Server

```bash
docker run -p 8000:8000 \
  -e DB_HOST=postgres \
  -e DB_PASSWORD=yourpassword \
  -e KAFKA_BROKERS=kafka:9092 \
  helios/analytics-service:phase3 api
```

### Run Kafka Consumer

```bash
docker run \
  -e DB_HOST=postgres \
  -e DB_PASSWORD=yourpassword \
  -e KAFKA_BROKERS=kafka:9092 \
  helios/analytics-service:phase3 consumer
```

## Kubernetes Deployment

The service is deployed with two separate pods:

1. **API Server** - Serves REST API requests
2. **Kafka Consumer** - Processes auction outcomes

```bash
# Deploy analytics service
kubectl apply -f kubernetes/services/04-analytics-service/

# Check deployments
kubectl get deployments -n helios -l component=analytics-service

# Check API logs
kubectl logs -n helios -l role=api --tail=50

# Check consumer logs
kubectl logs -n helios -l role=consumer --tail=50 -f
```

## API Examples

### Get All Outcomes

```bash
curl http://localhost:8000/api/outcomes/
```

### Get Specific Outcome

```bash
curl http://localhost:8000/api/outcomes/1/
```

### Filter by User

```bash
curl "http://localhost:8000/api/outcomes/?user_id=user-123"
```

### Get Only Winners

```bash
curl "http://localhost:8000/api/outcomes/winners/"
```

### Get Statistics

```bash
curl http://localhost:8000/api/outcomes/stats/
```

Response:
```json
{
  "total_outcomes": 10000,
  "total_wins": 7000,
  "total_losses": 3000,
  "win_rate": 70.0,
  "total_revenue": 5600.00,
  "average_win_price": 0.80,
  "average_bid_price": 0.75,
  "enriched_count": 8500
}
```

### Get Daily Statistics

```bash
curl http://localhost:8000/api/outcomes/daily_stats/
```

### Filter by Price Range

```bash
curl "http://localhost:8000/api/outcomes/?min_price=0.50&max_price=1.00"
```

### Pagination

```bash
# Page 2 with 50 results per page
curl "http://localhost:8000/api/outcomes/?page=2&page_size=50"
```

## Database Schema

The `AuctionOutcome` table has the following indexes for performance:

- Primary key on `id`
- Index on `timestamp` (descending)
- Composite index on `win_status, timestamp`
- Composite index on `user_id, timestamp`
- Composite index on `site_domain, timestamp`
- Individual indexes on `bid_id`, `user_id`, `site_domain`, `win_status`

## Management Commands

### Process Outcomes (Kafka Consumer)

```bash
# Run indefinitely
python manage.py process_outcomes

# Process max 100 messages then exit
python manage.py process_outcomes --max-messages 100

# Custom timeout
python manage.py process_outcomes --timeout 5000
```

### Database Operations

```bash
# Run migrations
python manage.py migrate

# Create migrations after model changes
python manage.py makemigrations

# Access Django shell
python manage.py shell

# Access database shell
python manage.py dbshell
```

## Monitoring

### Health Checks

The API endpoint `/api/outcomes/` serves as a health check endpoint.

### Metrics to Monitor

1. **API Performance**
   - Request latency
   - Requests per second
   - Error rate

2. **Consumer Performance**
   - Messages consumed per second
   - Consumer lag
   - Processing errors

3. **Database Performance**
   - Query execution time
   - Connection pool usage
   - Disk usage

### Log Queries

```bash
# Count processed outcomes
kubectl logs -n helios -l role=consumer | grep "Auction outcome saved" | wc -l

# Check for errors
kubectl logs -n helios -l role=consumer | grep '"level":"ERROR"'

# Get success rate
kubectl logs -n helios -l role=consumer --tail=1000 | \
  jq -r 'select(.message=="Kafka consumer stopped") | .success_count, .error_count'
```

## Troubleshooting

### Issue: Consumer not processing messages

**Check:**
1. Kafka topic exists and has messages
2. Database is accessible
3. Consumer is running

**Solution:**
```bash
# Check consumer logs
kubectl logs -n helios -l role=consumer --tail=100

# Restart consumer
kubectl rollout restart deployment/analytics-consumer-deployment -n helios
```

### Issue: API returning 500 errors

**Check:**
1. Database connection
2. Migrations are applied
3. Environment variables are set

**Solution:**
```bash
# Check API logs
kubectl logs -n helios -l role=api --tail=100

# Run migrations
kubectl exec -it deployment/analytics-api-deployment -n helios -- python manage.py migrate

# Restart API
kubectl rollout restart deployment/analytics-api-deployment -n helios
```

### Issue: Database migration errors

**Solution:**
```bash
# Access pod shell
kubectl exec -it deployment/analytics-api-deployment -n helios -- /bin/bash

# Check migration status
python manage.py showmigrations

# Fake migrations if needed (careful!)
python manage.py migrate --fake outcomes
```

## Performance Tuning

### Database Indexes

The model includes optimized indexes. For custom queries, add indexes:

```python
class Meta:
    indexes = [
        models.Index(fields=['custom_field', '-timestamp']),
    ]
```

### API Pagination

Adjust page size in `settings.py`:

```python
REST_FRAMEWORK = {
    'PAGE_SIZE': 100,  # Increase for fewer API calls
}
```

### Consumer Performance

Scale consumer replicas:

```bash
kubectl scale deployment/analytics-consumer-deployment -n helios --replicas=3
```

## Security Considerations

1. **Secret Key**: Use a strong `DJANGO_SECRET_KEY` in production
2. **Database Password**: Store in Kubernetes secrets
3. **ALLOWED_HOSTS**: Restrict to specific domains in production
4. **Debug Mode**: Always set `DEBUG=False` in production
5. **HTTPS**: Use TLS for API endpoints in production

## Integration with Phase 3

The Analytics Service completes the RTB pipeline:

1. Bid Request Handler → `bid_requests` topic
2. Bidding Logic Service → `bid_responses` topic
3. Auction Simulator → `auction_outcomes` topic
4. **Analytics Service** → PostgreSQL + REST API

Data flows from bid requests through enrichment, bidding, auction, and finally to persistent storage with queryable API access.

## Future Enhancements

- [ ] Add Prometheus metrics endpoint
- [ ] Implement data retention policies
- [ ] Add real-time analytics dashboards
- [ ] Implement data export functionality
- [ ] Add support for multiple currencies
- [ ] Implement caching layer (Redis)
- [ ] Add GraphQL API
- [ ] Implement data aggregation jobs

## License

Part of the Helios RTB Engine project.
