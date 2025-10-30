#!/usr/bin/env python3
"""Populate the Helios RTB pipeline with demo bid requests.

This script sends a configurable number of bid requests against the
bid-request-handler HTTP endpoint. It is handy when you want to quickly
seed the Kafka topics, auction simulator, and analytics database before a
live demo.
"""

from __future__ import annotations

import argparse
import random
import time
import uuid
from dataclasses import dataclass
from typing import Any, Dict

import requests  # type: ignore[import-not-found]

DEFAULT_USERS = [f"user-{i:03d}" for i in range(1, 21)]
DEFAULT_DOMAINS = [
    "news.example.com",
    "sports.example.com",
    "techblog.example.com",
    "finance.example.com",
]
AD_FORMATS = [["300x250"], ["728x90"], ["160x600"], ["970x250"]]


@dataclass
class DemoConfig:
    url: str
    count: int
    delay: float


Payload = Dict[str, Any]


def parse_args() -> DemoConfig:
    parser = argparse.ArgumentParser(description="Seed Helios RTB demo data")
    parser.add_argument(
        "--url",
        default="http://localhost:8080/bid",
        help="Bid handler URL (default: %(default)s)",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=30,
        help="Number of bid requests to send (default: %(default)s)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.25,
        help="Delay in seconds between bids (default: %(default)s)",
    )
    args = parser.parse_args()
    return DemoConfig(url=args.url, count=args.count, delay=args.delay)


def build_payload(sequence: int) -> Payload:
    user_id = random.choice(DEFAULT_USERS)
    domain = random.choice(DEFAULT_DOMAINS)
    page_slug = f"article-{sequence:03d}"
    payload: Payload = {
        "request_id": f"demo-{uuid.uuid4()}"[:18],
        "user_id": user_id,
        "site": {
            "domain": domain,
            "page": f"https://{domain}/{page_slug}",
        },
        "device": {
            "user_agent": "DemoBot/1.0",
            "ip": f"198.51.100.{random.randint(1, 254)}",
        },
        "ad_slots": [
            {
                "id": f"slot-{random.randint(1, 5)}",
                "min_bid": round(random.uniform(0.30, 1.20), 2),
                "format": random.choice(AD_FORMATS),
            }
        ],
    }
    return payload


def send_bid(config: DemoConfig, payload: Payload, index: int) -> None:
    slots = payload.get("ad_slots", [])
    slot_info: Dict[str, Any] = slots[0] if isinstance(slots, list) and slots else {}
    try:
        response = requests.post(config.url, json=payload, timeout=5)
        response.raise_for_status()
        status = response.status_code
        outcome = "accepted" if status == 202 else f"status={status}"
        print(
            f"[{index:02d}] {outcome} user={payload.get('user_id')} price_min={slot_info.get('min_bid')}"
        )
    except requests.RequestException as exc:
        print(f"[{index:02d}] failed user={payload['user_id']}: {exc}")


def main() -> None:
    config = parse_args()
    print(
        f"Seeding {config.count} bid requests to {config.url} with {config.delay:.2f}s spacing"
    )

    for idx in range(1, config.count + 1):
        payload = build_payload(idx)
        send_bid(config, payload, idx)
        time.sleep(config.delay)

    print("Done. Check analytics API or dashboard for new records.")


if __name__ == "__main__":
    main()
