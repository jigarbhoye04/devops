# Analytics Service - Quick Start Guide

## 🚀 Quick Start

### Local Development

1. **Install Dependencies**
   ```bash
   cd services/analytics-service
   pip install -r requirements.txt
   ```

2. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your database and Kafka settings
   ```

3. **Initialize Database**
   ```bash
   # Run migrations
   python manage.py migrate
   
   # Create superuser (optional)
   python manage.py createsuperuser
   ```

4. **Start Services**
   
   Terminal 1 - API Server:
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```
   
   Terminal 2 - Kafka Consumer:
   ```bash
   python manage.py process_outcomes
   ```

5. **Test API**
   ```bash
   # View all outcomes
   curl http://localhost:8000/api/outcomes/
   
   # View statistics
   curl http://localhost:8000/api/outcomes/stats/
   
   # Access admin interface
   # Open browser: http://localhost:8000/admin/
   ```

### Docker Deployment

1. **Build Image**
   ```bash
   docker build -t helios/analytics-service:phase3 .
   ```

2. **Run API Container**
   ```bash
   docker run -p 8000:8000 \
     -e DB_HOST=postgres \
     -e DB_PASSWORD=yourpassword \
     -e KAFKA_BROKERS=kafka:9092 \
     helios/analytics-service:phase3 api
   ```

3. **Run Consumer Container**
   ```bash
   docker run \
     -e DB_HOST=postgres \
     -e DB_PASSWORD=yourpassword \
     -e KAFKA_BROKERS=kafka:9092 \
     helios/analytics-service:phase3 consumer
   ```

### Kubernetes Deployment

1. **Deploy to Cluster**
   ```bash
   kubectl apply -f kubernetes/services/04-analytics-service/
   ```

2. **Verify Deployment**
   ```bash
   # Check pods
   kubectl get pods -n helios -l component=analytics-service
   
   # Check logs
   kubectl logs -n helios -l role=api --tail=50
   kubectl logs -n helios -l role=consumer -f
   ```

3. **Test API**
   ```bash
   # Port forward
   kubectl port-forward -n helios svc/analytics-service 8000:8000
   
   # Test endpoint
   curl http://localhost:8000/api/outcomes/stats/
   ```

## 📊 API Endpoints

### Core Endpoints
- `GET /api/outcomes/` - List all outcomes (paginated)
- `GET /api/outcomes/{id}/` - Get specific outcome
- `GET /api/outcomes/stats/` - Get statistics
- `GET /api/outcomes/winners/` - Get winning outcomes
- `GET /api/outcomes/daily_stats/` - Daily aggregations

### Query Parameters
- `user_id` - Filter by user
- `site_domain` - Filter by domain  
- `win_status` - Filter by win/loss (true/false)
- `min_price`, `max_price` - Price range
- `ordering` - Sort by field (e.g., `-timestamp`)
- `page`, `page_size` - Pagination

## 🔍 Management Commands

```bash
# Run Kafka consumer
python manage.py process_outcomes

# Process limited messages
python manage.py process_outcomes --max-messages 100

# Database migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Django shell
python manage.py shell

# Run tests
python manage.py test
```

## 🧪 Testing

```bash
# Test database models
python test_models.py

# Test API endpoints
curl http://localhost:8000/api/outcomes/
curl http://localhost:8000/api/outcomes/stats/
curl "http://localhost:8000/api/outcomes/?win_status=true"

# Access admin interface
# http://localhost:8000/admin/
```

## 📝 Environment Variables

### Required
- `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`
- `KAFKA_BROKERS`
- `KAFKA_TOPIC_AUCTION_OUTCOMES`

### Optional
- `DJANGO_SECRET_KEY` (required for production)
- `DEBUG` (default: False)
- `ALLOWED_HOSTS` (default: *)
- `KAFKA_CONSUMER_GROUP` (default: analytics-service-group)
- `LOG_LEVEL` (default: INFO)

## 🐛 Troubleshooting

### Database Connection Issues
```bash
# Test connection
python manage.py dbshell

# Run migrations
python manage.py migrate
```

### Consumer Not Processing
```bash
# Check Kafka topic
kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic auction_outcomes --from-beginning

# Restart consumer
# Ctrl+C and restart: python manage.py process_outcomes
```

### API Errors
```bash
# Check logs
tail -f /var/log/analytics-service.log

# Or in Kubernetes
kubectl logs -n helios -l role=api --tail=100
```

## 📚 Documentation

- [Full README](README.md)
- [Phase 3.2 Documentation](../../docs/phases/03.2-analytics-service.md)
- [Verification Script](../../docs/testing/phase3.2_verify.sh)

## ✅ Verification

Run the verification script:
```bash
bash docs/testing/phase3.2_verify.sh
```

## 🎯 Success Criteria

- [x] Django application running
- [x] Database migrations applied
- [x] API responding at /api/outcomes/
- [x] Kafka consumer processing messages
- [x] Auction outcomes being persisted
- [x] Statistics endpoint working
- [x] Admin interface accessible

## 🔗 Related Services

- Auction Simulator → Produces to `auction_outcomes` topic
- PostgreSQL → Stores persistent data
- Kafka → Message broker

## 📞 Support

For issues or questions, check:
1. Service logs
2. Phase documentation
3. README.md
4. Kubernetes deployment manifests
