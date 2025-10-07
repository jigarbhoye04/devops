from __future__ import annotations

import json
import os
import sys
import types
from datetime import datetime, timezone
from functools import lru_cache
from typing import Any, TYPE_CHECKING

from dotenv import load_dotenv

if TYPE_CHECKING:
    from kafka import KafkaConsumer  # type: ignore[import-not-found]


def log_json(level: str, message: str, *, fields: dict[str, Any] | None = None) -> None:
    entry: dict[str, Any] = {
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


@lru_cache(maxsize=1)
def _load_kafka_consumer() -> type["KafkaConsumer"]:
    try:
        from kafka import KafkaConsumer as imported_consumer  # type: ignore[import-not-found]
    except ModuleNotFoundError as exc:  # pragma: no cover - defensive path
        if exc.name not in {"kafka.vendor.six", "kafka.vendor.six.moves"}:
            raise
        _patch_kafka_vendor_six()
        from kafka import KafkaConsumer as imported_consumer  # type: ignore[import-not-found]
    return imported_consumer


@lru_cache(maxsize=1)
def _patch_kafka_vendor_six() -> None:
    try:
        import six  # type: ignore[import-not-found]
    except ModuleNotFoundError as exc:  # pragma: no cover - configuration error
        log_json(
            "fatal",
            "Missing six dependency required for kafka-python compatibility",
            fields={"module": "six"},
        )
        raise SystemExit(1) from exc

    vendor_module = sys.modules.get("kafka.vendor")
    if vendor_module is None:
        vendor_module = types.ModuleType("kafka.vendor")
        vendor_module.__path__ = []  # type: ignore[attr-defined]
        sys.modules["kafka.vendor"] = vendor_module

    six_module = sys.modules.get("kafka.vendor.six")
    if six_module is None:
        six_module = types.ModuleType("kafka.vendor.six")
        six_module.__dict__.update(six.__dict__)
        six_module.moves = six.moves  # type: ignore[attr-defined]
        setattr(vendor_module, "six", six_module)
        sys.modules["kafka.vendor.six"] = six_module

    if "kafka.vendor.six.moves" not in sys.modules:
        sys.modules["kafka.vendor.six.moves"] = sys.modules["kafka.vendor.six"].moves  # type: ignore[attr-defined]

    log_json(
        "warning",
        "Applied kafka-python vendor six compatibility patch",
        fields={"action": "fallback"},
    )


def create_consumer(brokers: str, topic: str, group_id: str) -> "KafkaConsumer":
    kafka_consumer_cls = _load_kafka_consumer()
    broker_list = [broker.strip() for broker in brokers.split(",") if broker.strip()]
    if not broker_list:
        log_json("fatal", "No valid Kafka brokers provided", fields={"brokers": brokers})
        raise SystemExit(1)

    consumer = kafka_consumer_cls(
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
