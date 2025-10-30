# Helios RTB Engine - Quick Start Guide

> **⚡ Get running in 5 minutes!**

This is the fastest path to get the Helios RTB Engine up and running on your Windows machine.

---

## Prerequisites (One-Time Setup)

### 1. Install WSL2

Open PowerShell as Administrator:

```powershell
wsl --install
```

Restart your computer when prompted.

### 2. Install Docker Desktop

1. Download from https://www.docker.com/products/docker-desktop
2. Install and enable "Use WSL 2 based engine"
3. Enable WSL integration for Ubuntu

### 3. Verify Installation

Open WSL terminal:

```bash
wsl
docker --version
docker compose version
```

---

## Run the Project (3 Commands)

```bash
# 1. Clone the repository
git clone https://github.com/jigarbhoye04/devops.git
cd devops

# 2. Run setup script
./setup.sh

# 3. Verify it works
./test.sh
```

That's it! The system is now running.

---

## Access the System

| Service | URL | What You'll See |
|---------|-----|-----------------|
| **Dashboard** | http://localhost:3000 | Analytics UI with charts |
| **Analytics API** | http://localhost:8000/api/outcomes/ | JSON data |
| **Health Check** | http://localhost:8080/healthz | OK status |

---

## Send Your First Bid

```bash
curl -X POST http://localhost:8080/bid \
  -H "Content-Type: application/json" \
  -d '{
    "request_id": "my-first-bid",
    "user_id": "user-001",
    "site": {"domain": "example.com"},
    "device": {"ip": "192.0.2.1"}
  }'
```

Then check http://localhost:3000 to see the result!

---

## What Just Happened?

The `./setup.sh` script:
1. ✅ Built 6 Docker images (Go, Python, Node.js services)
2. ✅ Started infrastructure (Kafka, Redis, PostgreSQL)
3. ✅ Deployed 6 microservices
4. ✅ Created 3 Kafka topics
5. ✅ Seeded sample user data in Redis
6. ✅ Ran database migrations

---

## Common Commands

```bash
# Start everything
./setup.sh

# Stop everything
docker compose -f helios-rtb-engine/docker-compose.full.yml down

# View logs
docker compose -f helios-rtb-engine/docker-compose.full.yml logs -f

# Check status
docker compose -f helios-rtb-engine/docker-compose.full.yml ps

# Run tests
./test.sh
```

---

## Troubleshooting

**Docker not working?**
```bash
# Check Docker is running
docker info

# If not, open Docker Desktop in Windows
```

**Port already in use?**
```bash
# Stop the stack first
docker compose -f helios-rtb-engine/docker-compose.full.yml down
./setup.sh
```

**Something broken?**
```bash
# Complete reset
docker compose -f helios-rtb-engine/docker-compose.full.yml down -v
./setup.sh --reset
```

---

## Next Steps

### Learn More
- **[COMPLETE_SETUP_GUIDE.md](COMPLETE_SETUP_GUIDE.md)** - Detailed walkthrough
- **[about.md](about.md)** - How the system works
- **[README.md](README.md)** - Full documentation

### Explore the System
```bash
# Query analytics
curl http://localhost:8000/api/outcomes/stats/ | jq '.'

# View user profiles
docker compose -f helios-rtb-engine/docker-compose.full.yml exec redis redis-cli KEYS "user-*"

# Watch Kafka messages
docker compose -f helios-rtb-engine/docker-compose.full.yml exec kafka \
  kafka-console-consumer --bootstrap-server kafka:29092 \
  --topic auction_outcomes --from-beginning --max-messages 5
```

### Test with Postman
1. Import `postman/helios-rtb-smoke.postman_collection.json`
2. Run the collection for comprehensive testing

---

## System Architecture (Simplified)

```
[Your Browser] → Dashboard (localhost:3000)
                      ↓
                Analytics API (localhost:8000)
                      ↓
                PostgreSQL Database
                      ↑
                Kafka Topics ← Auction Simulator
                      ↑
                Bidding Logic ← User Profiles (Redis)
                      ↑
                Bid Request Handler (localhost:8080)
                      ↑
                [Your curl command]
```

---

## Getting Help

1. Check [Troubleshooting](COMPLETE_SETUP_GUIDE.md#9-troubleshooting)
2. Review [TEST_AND_VERIFY.md](TEST_AND_VERIFY.md)
3. Check container logs: `docker compose -f helios-rtb-engine/docker-compose.full.yml logs <service-name>`

---

**Happy bidding!** 🚀

For the complete guide with all details, see [COMPLETE_SETUP_GUIDE.md](COMPLETE_SETUP_GUIDE.md)
