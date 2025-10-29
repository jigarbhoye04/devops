from __future__ import annotations

import json
import os
import sys
import time
import types
from datetime import datetime, timezone
from functools import lru_cache
from typing import TYPE_CHECKING, Any

import grpc
from dotenv import load_dotenv
from google.protobuf.json_format import MessageToDict
from pybreaker import CircuitBreaker, CircuitBreakerError

from . import user_profile_pb2, user_profile_pb2_grpc
from . import metrics

if TYPE_CHECKING:
    from kafka import KafkaConsumer, KafkaProducer  # type: ignore[import-not-found]


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
def _load_kafka_producer() -> type["KafkaProducer"]:
    try:
        from kafka import KafkaProducer as imported_producer  # type: ignore[import-not-found]
    except ModuleNotFoundError as exc:  # pragma: no cover - defensive path
        if exc.name not in {"kafka.vendor.six", "kafka.vendor.six.moves"}:
            raise
        _patch_kafka_vendor_six()
        from kafka import KafkaProducer as imported_producer  # type: ignore[import-not-found]
    return imported_producer


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


def create_producer(brokers: str) -> "KafkaProducer":
    kafka_producer_cls = _load_kafka_producer()
    broker_list = [broker.strip() for broker in brokers.split(",") if broker.strip()]
    if not broker_list:
        log_json("fatal", "No valid Kafka brokers provided", fields={"brokers": brokers})
        raise SystemExit(1)

    producer = kafka_producer_cls(
        bootstrap_servers=broker_list,
        value_serializer=lambda data: json.dumps(data).encode("utf-8"),
    )
    return producer


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
    start_time = time.time()
    try:
        result = USER_PROFILE_BREAKER.call(
            _invoke_user_profile_rpc,
            stub,
            user_id,
            timeout_seconds,
        )
        duration = time.time() - start_time
        metrics.user_profile_rpc_duration.observe(duration)
        metrics.user_profile_enrichment_total.labels(status='success').inc()
        
        # Update circuit breaker state (0 = closed)
        metrics.circuit_breaker_state.labels(service='user_profile').set(0)
        return result
    except CircuitBreakerError:
        metrics.user_profile_enrichment_total.labels(status='circuit_open').inc()
        metrics.circuit_breaker_state.labels(service='user_profile').set(1)  # 1 = open
        log_json(
            "error",
            "User profile circuit breaker open; skipping enrichment",
            fields={"user_id": user_id},
        )
    except grpc.RpcError as exc:
        duration = time.time() - start_time
        metrics.user_profile_rpc_duration.observe(duration)
        metrics.user_profile_enrichment_total.labels(status='failure').inc()
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


def calculate_bid_price_from_scores(
    interests: list[dict[str, Any]],
) -> tuple[float, str]:
    """
    Calculate bid price based on scored interests from user profile.
    
    Bidding Strategy:
    - Find interest with highest score
    - If highest score > 0.9: bid $1.20 (premium tier)
    - If highest score between 0.7-0.9: bid $0.85 (standard tier)
    - If highest score between 0.5-0.7: bid $0.60 (mid tier)
    - Otherwise: bid minimum $0.35 (base tier)
    
    Args:
        interests: List of interest dicts with 'name' and 'score'
        
    Returns:
        Tuple of (bid_price, winning_interest_name)
    """
    if not interests:
        log_json(
            "debug",
            "No interests provided, using minimum bid",
            fields={"bid_price": 0.35},
        )
        return 0.35, "none"
    
    # Find interest with highest score
    highest_interest = max(interests, key=lambda x: x.get("score", 0.0))
    highest_score = highest_interest.get("score", 0.0)
    interest_name = highest_interest.get("name", "unknown")
    
    # Determine bid price based on score
    if highest_score > 0.9:
        bid_price = 1.20
        tier = "premium"
    elif highest_score >= 0.7:
        bid_price = 0.85
        tier = "standard"
    elif highest_score >= 0.5:
        bid_price = 0.60
        tier = "mid"
    else:
        bid_price = 0.35
        tier = "base"
    
    log_json(
        "info",
        "Bid price calculated from interest scores",
        fields={
            "highest_interest": interest_name,
            "highest_score": highest_score,
            "bid_price": bid_price,
            "tier": tier,
        },
    )
    
    return bid_price, interest_name


def select_ad_creative(
    bid_price: float,
    winning_interest: str,
    enriched: bool,
) -> dict[str, Any]:
    """
    Select an ad creative based on bid price and user interest.
    
    Args:
        bid_price: The calculated bid price
        winning_interest: The interest with highest score
        enriched: Whether the bid was enriched with user profile
        
    Returns:
        Dict containing ad creative information
    """
    # Map interests to ad campaigns
    creative_mapping = {
        "technology": {
            "creative_id": "tech_001",
            "title": "Latest Tech Gadgets",
            "image_url": "https://cdn.helios.example/ads/tech_gadgets.jpg",
            "landing_url": "https://advertiser.example/tech",
        },
        "sports": {
            "creative_id": "sports_001",
            "title": "Premium Sports Equipment",
            "image_url": "https://cdn.helios.example/ads/sports_gear.jpg",
            "landing_url": "https://advertiser.example/sports",
        },
        "finance": {
            "creative_id": "finance_001",
            "title": "Smart Investment Solutions",
            "image_url": "https://cdn.helios.example/ads/finance_invest.jpg",
            "landing_url": "https://advertiser.example/finance",
        },
        "travel": {
            "creative_id": "travel_001",
            "title": "Exclusive Travel Deals",
            "image_url": "https://cdn.helios.example/ads/travel_deals.jpg",
            "landing_url": "https://advertiser.example/travel",
        },
    }
    
    # Select creative based on interest
    creative = creative_mapping.get(
        winning_interest.lower(),
        {
            "creative_id": "default_001",
            "title": "Discover Amazing Products",
            "image_url": "https://cdn.helios.example/ads/default.jpg",
            "landing_url": "https://advertiser.example/",
        },
    )
    
    # Add bid tier information
    creative["bid_tier"] = (
        "premium" if bid_price >= 0.10
        else "standard" if bid_price >= 0.05
        else "minimum"
    )
    # Ensure the dict value is a string to satisfy static type checkers
    creative["targeted"] = "true" if enriched else "false"
    
    return creative


def generate_bid_response(
    bid_request: dict[str, Any],
    user_profile: dict[str, Any] | None,
) -> dict[str, Any] | None:
    """
    Generate a bid response based on the bid request and user profile.
    
    Sophisticated bidding logic using scored interests:
    - Leverages interest scores from user profile
    - Calculates bid price based on highest scoring interest
    - Selects appropriate ad creative
    - Returns None if no bid should be placed
    """
    start_time = time.time()
    
    try:
        bid_request_id = bid_request.get("request_id", "unknown")
        user_id = bid_request.get("user_id", "unknown")
        
        # Extract profile data if available
        if user_profile and "profile" in user_profile:
            profile = user_profile["profile"]
            interests = profile.get("interests", [])
            
            # Calculate bid price from scored interests
            bid_price, winning_interest = calculate_bid_price_from_scores(interests)
            
            # Record bid price distribution
            metrics.bid_price_distribution.observe(bid_price)
            
            # Select ad creative
            ad_creative = select_ad_creative(bid_price, winning_interest, True)
            
            # Build enriched bid response
            bid_response = {
                "bid_request_id": bid_request_id,
                "user_id": user_id,
                "bid_price": round(bid_price, 2),
                "currency": "USD",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "enriched": True,
                "winning_interest": winning_interest,
                "interest_score": next(
                    (i["score"] for i in interests if i.get("name") == winning_interest),
                    0.0,
                ),
                "user_interests": [i.get("name", "") for i in interests],
                "ad_creative": ad_creative,
            }
            
        else:
            # No user profile - use default minimum bid
            log_json(
                "info",
                "No user profile available, using default minimum bid",
                fields={"user_id": user_id},
            )
            
            bid_price = 0.35  # Updated from 0.01 to match new minimum pricing
            metrics.bid_price_distribution.observe(bid_price)
            ad_creative = select_ad_creative(bid_price, "none", False)
            
            bid_response = {
                "bid_request_id": bid_request_id,
                "user_id": user_id,
                "bid_price": round(bid_price, 2),
                "currency": "USD",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "enriched": False,
                "ad_creative": ad_creative,
            }
        
        # Record metrics
        duration = time.time() - start_time
        metrics.bid_response_generation_duration.observe(duration)
        metrics.bid_requests_processed_total.labels(status='success').inc()
        
        return bid_response
        
    except Exception as exc:
        duration = time.time() - start_time
        metrics.bid_response_generation_duration.observe(duration)
        metrics.bid_requests_processed_total.labels(status='error').inc()
        log_json(
            "error",
            "Failed to generate bid response",
            fields={"error": str(exc)},
        )
        return None


def run() -> None:
    load_dotenv()

    brokers = get_env_var("KAFKA_BROKERS")
    topic = get_env_var("KAFKA_TOPIC_BID_REQUESTS")
    group_id = get_env_var("KAFKA_CONSUMER_GROUP")
    bid_response_topic = os.getenv("KAFKA_TOPIC_BID_RESPONSES", "bid_responses")
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

    # Start Prometheus metrics server
    metrics_port = int(os.getenv("METRICS_PORT", "8001"))
    try:
        metrics.start_metrics_server(metrics_port)
        log_json("info", f"Prometheus metrics server started on port {metrics_port}")
    except Exception as exc:
        log_json("error", f"Failed to start metrics server: {exc}")

    consumer = create_consumer(brokers, topic, group_id)
    producer = create_producer(brokers)
    channel, user_profile_stub = create_user_profile_client(user_profile_addr)
    log_json(
        "info",
        "Kafka consumer and producer started",
        fields={
            "topic": topic,
            "group_id": group_id,
            "brokers": brokers,
            "bid_response_topic": bid_response_topic,
            "user_profile_service": user_profile_addr,
        },
    )

    try:
        for record in consumer:
            metrics.active_bid_processing.inc()
            try:
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
                    metrics.bid_requests_processed_total.labels(status='parse_error').inc()
                    log_json(
                        "error",
                        "Failed to parse bid request JSON",
                        fields={"payload": raw_value, "error": str(exc)},
                    )
                    continue

                user_id = bid_request.get("user_id")
                if not isinstance(user_id, str) or not user_id:
                    metrics.bid_requests_processed_total.labels(status='invalid').inc()
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

                enriched_profile = None
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

                # Generate bid response
                bid_response = generate_bid_response(bid_request, enriched_profile)
                
                if bid_response is None:
                    metrics.bid_requests_processed_total.labels(status='no_bid').inc()
                    log_json(
                        "info",
                        "No bid generated for request",
                        fields={"bid_request_id": bid_request.get("request_id", "unknown")},
                    )
                    continue
                
                log_json(
                    "info",
                    "Bid response generated",
                    fields={
                        "bid_request_id": bid_response["bid_request_id"],
                        "bid_price": bid_response["bid_price"],
                        "enriched": bid_response["enriched"],
                        "winning_interest": bid_response.get("winning_interest", "none"),
                    },
                )

                # Produce bid response to Kafka
                try:
                    future = producer.send(bid_response_topic, value=bid_response)
                    future.get(timeout=10)  # Wait for acknowledgment
                    log_json(
                        "info",
                        "Bid response published",
                        fields={
                            "topic": bid_response_topic,
                            "bid_request_id": bid_response["bid_request_id"],
                        },
                    )
                except Exception as exc:
                    metrics.kafka_publish_errors_total.inc()
                    log_json(
                        "error",
                        "Failed to publish bid response",
                        fields={
                            "topic": bid_response_topic,
                            "bid_request_id": bid_response["bid_request_id"],
                            "error": str(exc),
                        },
                    )
            finally:
                metrics.active_bid_processing.dec()
                
    except KeyboardInterrupt:
        log_json("warning", "Consumer interrupted by user")
    finally:
        consumer.close()
        producer.close()
        channel.close()
        log_json("info", "Kafka consumer and producer stopped")


if __name__ == "__main__":
    run()
