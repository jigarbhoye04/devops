#!/usr/bin/env python3
from __future__ import annotations

import json
import random
import uuid


def generate_bid_request() -> dict[str, object]:
    """Generate a mock bid request payload."""

    ad_slots = []
    for slot_id in range(1, random.randint(2, 4)):
        ad_slots.append(
            {
                "id": f"slot-{slot_id}",
                "size": random.choice([[300, 250], [728, 90], [160, 600]]),
                "position": random.choice(["above_the_fold", "sidebar", "footer"]),
                "min_bid": round(random.uniform(0.05, 1.50), 2),
            }
        )

    return {
        "id": str(uuid.uuid4()),
        "timestamp": uuid.uuid1().time,
        "user": {
            "id": str(uuid.uuid4()),
            "segments": random.sample(
                ["sports", "travel", "tech", "finance", "gaming", "lifestyle"],
                k=3,
            ),
        },
        "site": {
            "domain": random.choice([
                "news.example.com",
                "sports.example.com",
                "techblog.example.com",
            ]),
            "page": random.choice([
                "https://news.example.com/politics",
                "https://sports.example.com/latest",
                "https://techblog.example.com/gadgets",
            ]),
        },
        "ad_slots": ad_slots,
    }


def main() -> None:
    bid_request = generate_bid_request()
    print(json.dumps(bid_request))


if __name__ == "__main__":
    main()
