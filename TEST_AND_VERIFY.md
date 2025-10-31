# Helios RTB Engine Test & Verification Guide

Follow these steps after running `./setup.sh` inside WSL to ensure every service is working end to end. All commands assume your current directory is `/mnt/c/Users/Jigar/Documents/GitHub/devops`.

## Automated Smoke Test
Run the bundled script for a repeatable verification pass. It drives the full pipeline, tails Kafka, inspects analytics (REST + gRPC), and points you to the comprehensive Postman collection for GUI-driven testing.
```bash
wsl
./test.sh
```
Add `--skip-postman` if you only need the command-line checks.

## 1. Confirm Container Health
```bash
wsl
docker compose -f helios-rtb-engine/docker-compose.full.yml ps
```
Expected: every service listed with `Up` status. If any container is `Exit` or `Restarting`, inspect logs:
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml logs <service-name>
```
Use the `container_name` values (for example `helios-bid-handler`).

## 2. Validate Redis User Profiles
Check that the seeding step populated Redis:
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec redis \
  redis-cli KEYS "user-*"
```
Expected: a handful of user IDs such as `user-001`. Optionally inspect a profile:
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec redis \
  redis-cli GET user-001 | jq .
```
Install `jq` in your WSL distro if you want pretty JSON (`sudo apt install jq`).

## 3. Send a Sample Bid Request
Create a sample payload and submit it to the bid ingestion API:
```bash
cat <<'EOF' > /tmp/helios-bid.json
{
  "request_id": "demo-request-001",
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
EOF

curl -i -X POST \
  -H "Content-Type: application/json" \
  --data @/tmp/helios-bid.json \
  http://localhost:8080/bid
```
Expected response: HTTP `202 Accepted`. Review request metrics:
```bash
curl -s http://localhost:2112/metrics | grep bid_requests_total
```

### Postman (Manual) Verification
Import `postman/helios-rtb-smoke.postman_collection.json` for a ready-made suite that covers:
- Health and metrics endpoints (`/healthz`, `/metrics`, dashboard health)
- Multiple bid submission scenarios (enriched, fallback, missing user)
- Full analytics API surface (`/api/outcomes` filters, stats, winners, daily stats)
- gRPC `GetUserProfile` call (after import, open the request, click **Select Proto File**, and point it to `helios-rtb-engine/proto/user_profile.proto`).

You can also maintain ad-hoc requests manually:
1. Add a `POST {{bid_base_url}}/bid` with the sample payload.
2. Duplicate it for other user IDs or payload permutations.
3. Add reads against `{{analytics_base_url}}/api/outcomes/` to verify persistence.
4. Use the gRPC tab in Postman with the same proto file to fetch user profiles.

## 4. Inspect Bid Responses in Kafka
Confirm the bidding logic produced a response:
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic bid_responses \
    --from-beginning \
    --max-messages 1
```
You should see a JSON message with fields such as `bid_price`, `enriched`, and `winning_interest`. Stop the consumer with `Ctrl+C` after the message prints.

## 5. Inspect Auction Outcomes
Validate the auction simulator generated an outcome for the same bid:
```bash
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-console-consumer \
    --bootstrap-server kafka:29092 \
    --topic auction_outcomes \
    --from-beginning \
    --max-messages 1
```
Expected: JSON including `win_status`, `win_price`, and `auction_timestamp`.

## 6. Verify Analytics Persistence & API
1. Confirm rows exist in PostgreSQL:
   ```bash
   docker compose -f helios-rtb-engine/docker-compose.full.yml exec postgres \
     psql -U helios -d helios_analytics -c "SELECT bid_id, win_status, win_price, created_at FROM outcomes_auctionoutcome ORDER BY created_at DESC LIMIT 5;"
   ```
2. Check the REST API:
   ```bash
   curl -s http://localhost:8000/api/outcomes/ | jq '.results[0]'
   ```
   You should see the latest auction outcome with enrichment details.

## 7. Validate the Advertiser Dashboard
Open `http://localhost:3000` in a Windows browser. The dashboard should load, showing aggregate metrics pulled from the analytics API. Use the browser dev tools network tab if data does not render; look for successful calls to `http://localhost:8000/api/outcomes/`.

## 8. Metrics & Observability Spot Checks
- Bid handler metrics: `curl -s http://localhost:2112/metrics | head`
- Bidding logic metrics: `curl -s http://localhost:8001/metrics | head`
- Django health (API list doubles as health): `curl -I http://localhost:8000/api/outcomes/`
- Dashboard health endpoint: `curl -I http://localhost:3000/api/health`

## 9. Service-Level Tests (Optional)
Run targeted automated tests inside their containers:
```bash
# Analytics service Django tests
wsl
docker compose -f helios-rtb-engine/docker-compose.full.yml exec analytics-service-api \
  python manage.py test

# Auction simulator unit tests
wsl
docker compose -f helios-rtb-engine/docker-compose.full.yml exec auction-simulator \
  npm test

# Bid request handler lint (Go vet example)
wsl
docker compose -f helios-rtb-engine/docker-compose.full.yml exec bid-request-handler \
  go test ./...
```
Adapt or extend these commands as needed for deeper validation.

## 10. Troubleshooting Tips
- **Kafka consumer hangs:** Ensure topics exist by rerunning `./setup.sh --skip-build` (topics are recreated every run).
- **Analytics API 500 errors:** Check migrations (`docker compose exec analytics-service-api python manage.py showmigrations`). The entrypoint reruns migrations on start; restart the container if needed.
- **Dashboard cannot reach API:** Verify CORS/hostnames by confirming `NEXT_PUBLIC_ANALYTICS_API_URL` points to `http://localhost:8000` inside `docker-compose.full.yml`.
- **Reset everything:**
  ```bash
  wsl
  docker compose -f helios-rtb-engine/docker-compose.full.yml down -v
  ./setup.sh
  ```
