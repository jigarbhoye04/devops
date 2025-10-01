#!/usr/bin/env python3
from __future__ import annotations

import json
import random
import uuid
from pathlib import Path

INTERESTS = ["sports", "fitness", "travel", "tech", "finance", "gaming", "music", "fashion"]
OUTPUT_DIR = Path(__file__).resolve().parent / "data"
OUTPUT_DIR.mkdir(exist_ok=True)


def random_profile(user_id: str) -> dict[str, object]:
    interests = random.sample(INTERESTS, k=random.randint(2, 4))
    return {
        "user_id": user_id,
        "locale": random.choice(["en_US", "en_GB", "de_DE", "fr_FR"]),
        "interests": [
            {"category": category, "score": round(random.uniform(0.2, 1.0), 2)}
            for category in interests
        ],
    }


def random_bid_request(user_id: str) -> dict[str, object]:
    return {
        "request_id": str(uuid.uuid4()),
        "user_id": user_id,
        "placement": random.choice(["sidebar", "banner", "video"]),
        "floor": round(random.uniform(0.01, 1.0), 2),
    }


def main(batch_size: int = 100) -> None:
    profiles, requests = [], []

    for _ in range(batch_size):
        user_id = str(uuid.uuid4())
        profiles.append(random_profile(user_id))
        requests.append(random_bid_request(user_id))

    (OUTPUT_DIR / "profiles.jsonl").write_text("\n".join(json.dumps(p) for p in profiles))
    (OUTPUT_DIR / "bid_requests.jsonl").write_text("\n".join(json.dumps(r) for r in requests))


if __name__ == "__main__":
    main()
