from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from typing import Any

from dotenv import load_dotenv
from kafka import KafkaConsumer


def log_json(level: str, message: str, *, fields: dict[str, Any] | None = None) -> None:
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "level": level,
        "message": message,
    }
    if fields:
        entry["fields"] = fields
    sys.stdout.write(json.dumps(entry) + "\n")
    sys.stdout.flush()


def get_env_var(name: str) -> str:
    value = os.getenv(name)
    if not value:
        log_json("fatal", "Missing required environment variable", fields={"env": name})
        raise SystemExit(1)
    return value


def create_consumer(brokers: str, topic: str, group_id: str) -> KafkaConsumer:
    broker_list = [broker.strip() for broker in brokers.split(",") if broker.strip()]
    if not broker_list:
        log_json("fatal", "No valid Kafka brokers provided", fields={"brokers": brokers})
        raise SystemExit(1)

    consumer = KafkaConsumer(
        topic,
        bootstrap_servers=broker_list,
        group_id=group_id,
        auto_offset_reset="earliest",
        enable_auto_commit=True,
        value_deserializer=lambda data: data.decode("utf-8"),
    )
    return consumer


def run() -> None:
    load_dotenv()

    brokers = get_env_var("KAFKA_BROKERS")
    topic = get_env_var("KAFKA_TOPIC_BID_REQUESTS")
    group_id = get_env_var("KAFKA_CONSUMER_GROUP")

    consumer = create_consumer(brokers, topic, group_id)
    log_json(
        "info",
        "Kafka consumer started",
        fields={"topic": topic, "group_id": group_id, "brokers": brokers},
    )

    try:
        for record in consumer:
            log_json(
                "info",
                "Bid request received",
                fields={
                    "topic": record.topic,
                    "partition": record.partition,
                    "offset": record.offset,
                    "value": record.value,
                },
            )
    except KeyboardInterrupt:
        log_json("warning", "Consumer interrupted by user")
    finally:
        consumer.close()
        log_json("info", "Kafka consumer stopped")


if __name__ == "__main__":
    run()
