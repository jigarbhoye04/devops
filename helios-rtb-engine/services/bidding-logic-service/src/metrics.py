"""
Prometheus metrics for the Bidding Logic Service
"""
from prometheus_client import Counter, Histogram, Gauge, start_http_server

# Metrics
bid_requests_processed_total = Counter(
    'bid_requests_processed_total',
    'Total number of bid requests processed',
    ['status']  # success, error, no_bid
)

bid_response_generation_duration = Histogram(
    'bid_response_generation_duration_seconds',
    'Time taken to generate a bid response',
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0)
)

user_profile_enrichment_total = Counter(
    'user_profile_enrichment_total',
    'Total number of user profile enrichment attempts',
    ['status']  # success, failure, circuit_open
)

user_profile_rpc_duration = Histogram(
    'user_profile_rpc_duration_seconds',
    'Time taken for user profile RPC calls',
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0)
)

bid_price_distribution = Histogram(
    'bid_price_distribution_usd',
    'Distribution of bid prices in USD',
    buckets=(0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 1.0, 1.5, 2.0, 5.0)
)

kafka_publish_errors_total = Counter(
    'kafka_publish_errors_total',
    'Total number of Kafka publish errors'
)

active_bid_processing = Gauge(
    'active_bid_processing',
    'Number of bids currently being processed'
)

circuit_breaker_state = Gauge(
    'circuit_breaker_state',
    'Circuit breaker state (0=closed, 1=open, 2=half_open)',
    ['service']
)


def start_metrics_server(port: int = 8001) -> None:
    """
    Start the Prometheus metrics HTTP server
    
    Args:
        port: Port to expose metrics on (default: 8001)
    """
    start_http_server(port)
