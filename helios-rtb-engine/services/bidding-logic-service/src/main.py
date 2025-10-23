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
DEFAULT_USER_PROFILE_TIMEOUT = 2.0


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
        return USER_PROFILE_BREAKER.call(
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


def run() -> None:
    load_dotenv()

    brokers = get_env_var("KAFKA_BROKERS")
    topic = get_env_var("KAFKA_TOPIC_BID_REQUESTS")
    group_id = get_env_var("KAFKA_CONSUMER_GROUP")
    user_profile_addr = get_env_var("USER_PROFILE_SVC_ADDR")

    timeout_env = os.getenv("USER_PROFILE_SVC_TIMEOUT", str(DEFAULT_USER_PROFILE_TIMEOUT))
    try:
        user_profile_timeout = float(timeout_env)
    except ValueError:
        log_json(
            "warning",
            "Invalid USER_PROFILE_SVC_TIMEOUT; using default",
            fields={"value": timeout_env},
        )
        user_profile_timeout = DEFAULT_USER_PROFILE_TIMEOUT

    consumer = create_consumer(brokers, topic, group_id)
    channel, user_profile_stub = create_user_profile_client(user_profile_addr)
    log_json(
        "info",
        "Kafka consumer started",
        fields={
            "topic": topic,
            "group_id": group_id,
            "brokers": brokers,
            "user_profile_service": user_profile_addr,
        },
    )

    try:
        for record in consumer:
            raw_value = record.value
            log_json(
                "info",
                "Bid request received",
                fields={
                    "topic": record.topic,
                    "partition": record.partition,
                    "offset": record.offset,
                    "value": raw_value,
                },
            )
            try:
                bid_request = json.loads(raw_value)
            except json.JSONDecodeError as exc:
                log_json(
                    "error",
                    "Failed to parse bid request JSON",
                    fields={"payload": raw_value, "error": str(exc)},
                )
                continue

            user_id = bid_request.get("user_id")
            if not isinstance(user_id, str) or not user_id:
                log_json(
                    "warning",
                    "Bid request missing user_id; skipping enrichment",
                    fields={"bid_request": bid_request},
                )
                continue

            log_json(
                "info",
                "Processing bid request",
                fields={"user_id": user_id, "bid_request": bid_request},
            )

            profile_response = fetch_user_profile(
                user_profile_stub,
                user_id,
                user_profile_timeout,
            )

            if profile_response is not None:
                enriched_profile = MessageToDict(
                    profile_response,
                    preserving_proto_field_name=True,
                )
                log_json(
                    "info",
                    "Bid request enriched",
                    fields={
                        "user_id": user_id,
                        "enriched_profile": enriched_profile,
                    },
                )
            else:
                log_json(
                    "warning",
                    "Proceeding without user profile enrichment",
                    fields={"user_id": user_id},
                )
    except KeyboardInterrupt:
        log_json("warning", "Consumer interrupted by user")
    finally:
        consumer.close()
        channel.close()
        log_json("info", "Kafka consumer stopped")


if __name__ == "__main__":
    run()
