from __future__ import annotations

import json
import os
import sys
import types
from datetime import datetime, timezone
from functools import lru_cache
from typing import TYPE_CHECKING, Any

import grpc
from dotenv import load_dotenv
from google.protobuf.json_format import MessageToDict
from pybreaker import CircuitBreaker, CircuitBreakerError

from . import user_profile_pb2, user_profile_pb2_grpc

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


USER_PROFILE_BREAKER = CircuitBreaker(fail_max=5, reset_timeout=30)


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


def create_user_profile_client(
    address: str,
) -> tuple[grpc.Channel, Any]:
    channel = grpc.insecure_channel(address)
    stub = user_profile_pb2_grpc.UserProfileServiceStub(channel)
    return channel, stub


def _invoke_user_profile_rpc(
    stub: Any,
    user_id: str,
    timeout_seconds: float,
) -> Any:
    request = user_profile_pb2.GetUserProfileRequest(user_id=user_id)  # type: ignore[attr-defined]
    return stub.GetUserProfile(request, timeout=timeout_seconds)


def fetch_user_profile(
    stub: Any,
    user_id: str,
    timeout_seconds: float,
) -> Any | None:
    try:
        response = USER_PROFILE_BREAKER.call(
            _invoke_user_profile_rpc,
            stub,
            user_id,
            timeout_seconds,
        )
    except CircuitBreakerError:
        log_json(
            "error",
            "User profile circuit breaker open; skipping enrichment",
            fields={"user_id": user_id},
        )
        return None
    except grpc.RpcError as exc:
        log_json(
            "error",
            "User profile RPC failed",
            fields={
                "user_id": user_id,
                "rpc_code": exc.code().name if hasattr(exc, "code") else "unknown",
                "details": exc.details() if hasattr(exc, "details") else None,
            },
        )
        return None

    log_json(
        "info",
        "User profile response received",
        fields={
            "user_id": user_id,
            "response": MessageToDict(response, preserving_proto_field_name=True),
        },
    )
    return response


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
