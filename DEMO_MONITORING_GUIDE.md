# Helios RTB Demo & Monitoring Checklist

This guide explains, in plain English, how to demo the Helios RTB Engine and track all moving parts while you present it to mentors or teammates. Follow the steps in order. Everything works from WSL with Docker running.

---

## 1. Before the Demo

1. **Start the stack**
   ```bash
   wsl
   cd /mnt/c/Users/Jigar/Documents/GitHub/devops
   ./setup.sh --skip-build
   ```
2. **Basic readiness check**
   ```bash
   ./pre_postman_check.sh
   ```
   If you see "All systems ready", move on. If not, fix the failing service.
3. **Optional: reset data** (only if you want a clean run)
   ```bash
   docker compose -f helios-rtb-engine/docker-compose.full.yml down -v
   ./setup.sh --skip-build
   ```

---

## 2. Monitoring Dashboard (Browser)

Keep two browser tabs open during the demo:

1. **Advertiser Dashboard (Next.js UI)** – `http://localhost:3000`
   - Shows aggregated results after we send bids.
   - Refresh the page after each bidding round to display new metrics.

2. **Prometheus Metrics (optional)**
   - Instead of a GUI, we use raw `/metrics` endpoints.
   - Open these URLs in separate tabs:
     - Bid handler metrics: `http://localhost:2112/metrics`
     - Bidding logic metrics: `http://localhost:8001/metrics`

Use the browser’s find feature (Ctrl+F) to search for metric names like `bid_requests_total` or `bid_requests_processed_total`.

---

## 3. Live Terminal Windows

Keep two WSL terminals side by side for real-time feedback.

### Terminal A – Logs
Run each command in its own tab when needed.
```bash
# Bid request handler logs (HTTP ingestion)
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f bid-request-handler

# Bidding logic (Kafka consumer + user enrichment)
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f bidding-logic-service

# Auction simulator (determines winners)
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f auction-simulator

# Analytics API (Django)
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f analytics-service-api
```

### Terminal B – Monitoring Commands
Keep this terminal ready for quick commands.
```bash
# Show all containers and health status
wsl docker compose -f helios-rtb-engine/docker-compose.full.yml ps

# Check Redis seed data
wsl docker compose -f helios-rtb-engine/docker-compose.full.yml exec redis redis-cli KEYS "user-*"

# View latest analytics rows
wsl docker compose -f helios-rtb-engine/docker-compose.full.yml exec postgres psql -U helios -d helios_analytics -c "SELECT bid_id, user_id, win_status, win_price, created_at FROM outcomes_auctionoutcome ORDER BY created_at DESC LIMIT 5;"
```

---

## 4. Automated End-to-End Test

Run the full script before the demo and again during the presentation if time allows. It covers REST, Kafka, database, and gRPC checks.
```bash
./test.sh
```
Key sections to highlight as the script runs:
- **Bid Injection** – sends enriched and fallback bids.
- **Kafka Topics** – prints messages consumed from `bid_responses` and `auction_outcomes`.
- **Analytics Deep Dive** – shows filtered results, stats, daily breakdown.
- **User Profile gRPC Probe** – demonstrates direct gRPC calls to the user service.

If you need quicker feedback, run individual segments from `test.sh` (for example, just the analytics curl commands).

---

## 5. Postman Demo (Visual Walkthrough)

1. Import `postman/helios-rtb-smoke.postman_collection.json`.
2. Set collection variables (already pre-filled for localhost). If the gRPC request fails, click **Select Proto File** and point to `helios-rtb-engine/proto/user_profile.proto`.
3. Execute folders in this order:
   - **Health Checks** – prove that every service responds.
   - **Bid Submission** – enriched, fallback, and edge-case bids.
   - **Analytics API** – run the list request to capture an `id`, then run the detail, filters, stats, winners, and daily stats.
   - **Monitoring** – metrics endpoints.
   - **gRPC** – fetch a profile for `user-001` and `user-anonymous`.

Postman displays the response JSON and test results (pass/fail) immediately, which is great for live demos.

---

## 6. Simulating Multiple Bidders

Show how the system handles load by running the helper script (sends bids back-to-back and ensures wins thanks to the elevated auction probability).
```bash
wsl python3 helios-rtb-engine/scripts/populate_demo_data.py --count 40 --delay 0.15
```
After the burst:
- Check metrics (`/metrics` endpoints should show increased counters).
- Run analytics queries to highlight new entries and win rates.
- Refresh the dashboard to show updated charts.

---

## 7. Highlight Talking Points

While running the demo, mention:
- **Structured logs** – run `logs -f` commands to show JSON logs with timestamps and metadata.
- **Kafka flow** – emphasize how bid requests and responses move through topics (`bid_requests`, `bid_responses`, `auction_outcomes`).
- **User enrichment** – gRPC call demonstrates retrieving profiles from Redis.
- **Analytics persistence** – PostgreSQL table, Django API, and React dashboard all showing the same data.
- **Security & config** – everything driven by environment variables; metrics exposed for observability.

---

## 8. After the Demo

1. Stop the stack when finished:
   ```bash
   docker compose -f helios-rtb-engine/docker-compose.full.yml down
   ```
2. (Optional) clean up images and volumes if you need disk space:
   ```bash
   docker system prune -f
   docker volume rm helios-rtb-engine_postgres_data || true
   ```

---

Keep this guide handy during the presentation. The mix of automated scripts (for hard proof) and Postman/browser views (for visual impact) ensures mentors see every part of the Helios RTB Engine working together.
