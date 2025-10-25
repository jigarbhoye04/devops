"""
Django management command to process auction outcomes from Kafka.

This command consumes messages from the auction_outcomes Kafka topic
and persists them to the PostgreSQL database.

Usage:
    python manage.py process_outcomes
"""

import json
import sys
import types
from datetime import datetime
from decimal import Decimal, InvalidOperation
from functools import lru_cache

from django.core.management.base import BaseCommand
from django.conf import settings
from django.utils.dateparse import parse_datetime

from outcomes.models import AuctionOutcome


def log_json(level, message, **fields):
    """Log structured JSON message to stdout."""
    log_entry = {
        "timestamp": datetime.utcnow().isoformat() + 'Z',
        "level": level.upper(),
        "message": message,
        **fields
    }
    print(json.dumps(log_entry), flush=True)


@lru_cache(maxsize=1)
def _patch_kafka_vendor_six():
    """Patch kafka-python's vendored six module."""
    try:
        import six
    except ModuleNotFoundError as exc:
        log_json("fatal", "Missing six dependency required for kafka-python compatibility")
        raise SystemExit(1) from exc

    vendor_module = sys.modules.get("kafka.vendor")
    if vendor_module is None:
        vendor_module = types.ModuleType("kafka.vendor")
        vendor_module.__path__ = []
        sys.modules["kafka.vendor"] = vendor_module

    six_module = sys.modules.get("kafka.vendor.six")
    if six_module is None:
        six_module = types.ModuleType("kafka.vendor.six")
        six_module.__dict__.update(six.__dict__)
        six_module.moves = six.moves
        setattr(vendor_module, "six", six_module)
        sys.modules["kafka.vendor.six"] = six_module

    if "kafka.vendor.six.moves" not in sys.modules:
        sys.modules["kafka.vendor.six.moves"] = sys.modules["kafka.vendor.six"].moves

    log_json("warning", "Applied kafka-python vendor six compatibility patch")


@lru_cache(maxsize=1)
def _load_kafka_consumer():
    """Load KafkaConsumer with six compatibility patch if needed."""
    try:
        from kafka import KafkaConsumer
    except ModuleNotFoundError as exc:
        if exc.name not in {"kafka.vendor.six", "kafka.vendor.six.moves"}:
            raise
        _patch_kafka_vendor_six()
        from kafka import KafkaConsumer
    return KafkaConsumer


class Command(BaseCommand):
    """
    Django management command to consume auction outcomes from Kafka.
    """
    
    help = 'Consume auction outcomes from Kafka and persist to database'
    
    def add_arguments(self, parser):
        """Add custom command arguments."""
        parser.add_argument(
            '--max-messages',
            type=int,
            default=None,
            help='Maximum number of messages to process before exiting (default: unlimited)'
        )
        parser.add_argument(
            '--timeout',
            type=int,
            default=1000,
            help='Consumer timeout in milliseconds (default: 1000)'
        )
    
    def handle(self, *args, **options):
        """Main command handler."""
        max_messages = options['max_messages']
        timeout_ms = options['timeout']
        
        # Get configuration from Django settings
        brokers = settings.KAFKA_BROKERS
        topic = settings.KAFKA_TOPIC_AUCTION_OUTCOMES
        group_id = settings.KAFKA_CONSUMER_GROUP
        
        log_json(
            "info",
            "Starting auction outcomes consumer",
            brokers=brokers,
            topic=topic,
            group_id=group_id,
            max_messages=max_messages,
        )
        
        # Create Kafka consumer
        KafkaConsumer = _load_kafka_consumer()
        broker_list = [b.strip() for b in brokers.split(',') if b.strip()]
        
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=broker_list,
            group_id=group_id,
            auto_offset_reset='earliest',
            enable_auto_commit=True,
            value_deserializer=lambda data: data.decode('utf-8'),
            consumer_timeout_ms=timeout_ms,
        )
        
        log_json("info", "Kafka consumer started", topic=topic)
        
        message_count = 0
        success_count = 0
        error_count = 0
        
        try:
            for record in consumer:
                message_count += 1
                
                try:
                    # Parse message
                    raw_value = record.value
                    log_json(
                        "debug",
                        "Message received",
                        topic=record.topic,
                        partition=record.partition,
                        offset=record.offset,
                    )
                    
                    # Deserialize JSON
                    try:
                        outcome_data = json.loads(raw_value)
                    except json.JSONDecodeError as exc:
                        log_json(
                            "error",
                            "Failed to parse JSON",
                            payload=raw_value,
                            error=str(exc),
                        )
                        error_count += 1
                        continue
                    
                    # Create AuctionOutcome instance
                    auction_outcome = self.create_auction_outcome(outcome_data)
                    
                    if auction_outcome:
                        success_count += 1
                        log_json(
                            "info",
                            "Auction outcome saved",
                            bid_id=auction_outcome.bid_id,
                            win_status=auction_outcome.win_status,
                            win_price=str(auction_outcome.win_price),
                        )
                    else:
                        error_count += 1
                    
                    # Check if max messages reached
                    if max_messages and message_count >= max_messages:
                        log_json(
                            "info",
                            "Max messages reached, stopping consumer",
                            max_messages=max_messages,
                        )
                        break
                        
                except Exception as exc:
                    log_json(
                        "error",
                        "Error processing message",
                        error=str(exc),
                        error_type=type(exc).__name__,
                    )
                    error_count += 1
                    
        except KeyboardInterrupt:
            log_json("warning", "Consumer interrupted by user")
        finally:
            consumer.close()
            log_json(
                "info",
                "Kafka consumer stopped",
                total_messages=message_count,
                success_count=success_count,
                error_count=error_count,
            )
    
    def create_auction_outcome(self, data):
        """
        Create and save an AuctionOutcome instance from Kafka message data.
        
        Args:
            data: Dictionary containing auction outcome data
            
        Returns:
            AuctionOutcome instance if successful, None otherwise
        """
        try:
            # Extract required fields
            bid_id = data.get('bid_request_id') or data.get('bid_id', 'unknown')
            user_id = data.get('user_id', 'unknown')
            win_status = data.get('win_status', False)
            
            # Extract numeric fields with validation
            try:
                win_price = Decimal(str(data.get('win_price', 0)))
            except (InvalidOperation, ValueError, TypeError):
                win_price = Decimal('0.00')
            
            try:
                bid_price = Decimal(str(data.get('bid_price', 0)))
            except (InvalidOperation, ValueError, TypeError):
                bid_price = Decimal('0.00')
            
            # Extract optional fields
            site_domain = data.get('site_domain') or data.get('page_url', '')
            currency = data.get('currency', 'USD')
            enriched = data.get('enriched', False)
            user_interests = data.get('user_interests', [])
            
            # Parse timestamps
            auction_timestamp = None
            auction_ts = data.get('auction_timestamp')
            if auction_ts:
                auction_timestamp = parse_datetime(auction_ts)
            
            # Create and save the outcome
            outcome = AuctionOutcome.objects.create(
                bid_id=bid_id,
                user_id=user_id,
                site_domain=site_domain[:255] if site_domain else '',
                win_status=bool(win_status),
                win_price=win_price,
                bid_price=bid_price,
                currency=currency[:3] if currency else 'USD',
                enriched=bool(enriched),
                auction_timestamp=auction_timestamp,
                user_interests=user_interests if isinstance(user_interests, list) else [],
                raw_data=data,
            )
            
            return outcome
            
        except Exception as exc:
            log_json(
                "error",
                "Failed to create AuctionOutcome",
                error=str(exc),
                error_type=type(exc).__name__,
                data=data,
            )
            return None
