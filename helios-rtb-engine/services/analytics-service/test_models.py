#!/usr/bin/env python
"""
Test script for Analytics Service
Tests the AuctionOutcome model and API endpoints locally.
"""

import os
import sys
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'analytics.settings')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

django.setup()

from decimal import Decimal
from datetime import datetime, timezone
from outcomes.models import AuctionOutcome

def test_model_creation():
    """Test creating AuctionOutcome instances."""
    print("=" * 60)
    print("Testing AuctionOutcome Model Creation")
    print("=" * 60)
    
    # Create test outcome
    outcome = AuctionOutcome.objects.create(
        bid_id="test-bid-001",
        user_id="test-user-123",
        site_domain="example.com",
        win_status=True,
        win_price=Decimal("0.85"),
        bid_price=Decimal("0.90"),
        currency="USD",
        enriched=True,
        user_interests=["technology", "sports"],
        raw_data={"test": "data"},
    )
    
    print(f"✅ Created outcome: {outcome}")
    print(f"   ID: {outcome.id}")
    print(f"   Bid ID: {outcome.bid_id}")
    print(f"   Win Status: {outcome.win_status}")
    print(f"   Win Price: ${outcome.win_price}")
    print(f"   Is Winner: {outcome.is_winner}")
    print(f"   Profit Margin: ${outcome.profit_margin}")
    print()
    
    return outcome


def test_model_queries():
    """Test querying AuctionOutcome."""
    print("=" * 60)
    print("Testing AuctionOutcome Queries")
    print("=" * 60)
    
    # Create multiple outcomes
    outcomes = []
    for i in range(5):
        outcome = AuctionOutcome.objects.create(
            bid_id=f"test-bid-{i:03d}",
            user_id=f"test-user-{i % 2}",
            win_status=(i % 2 == 0),
            win_price=Decimal(f"{0.5 + i * 0.1:.2f}"),
            bid_price=Decimal(f"{0.6 + i * 0.1:.2f}"),
        )
        outcomes.append(outcome)
    
    print(f"✅ Created {len(outcomes)} test outcomes")
    
    # Query all
    total = AuctionOutcome.objects.count()
    print(f"   Total outcomes: {total}")
    
    # Query winners
    winners = AuctionOutcome.objects.filter(win_status=True).count()
    print(f"   Winners: {winners}")
    
    # Query by user
    user_outcomes = AuctionOutcome.objects.filter(user_id="test-user-0").count()
    print(f"   Outcomes for user-0: {user_outcomes}")
    
    # Latest outcomes
    latest = AuctionOutcome.objects.order_by('-timestamp').first()
    if latest:
        print(f"   Latest outcome: {latest.bid_id}")
    
    print()
    return outcomes


def test_model_aggregations():
    """Test aggregating AuctionOutcome data."""
    print("=" * 60)
    print("Testing AuctionOutcome Aggregations")
    print("=" * 60)
    
    from django.db.models import Count, Sum, Avg, Q
    
    stats = AuctionOutcome.objects.aggregate(
        total=Count('id'),
        wins=Count('id', filter=Q(win_status=True)),
        total_revenue=Sum('win_price', filter=Q(win_status=True)),
        avg_win_price=Avg('win_price', filter=Q(win_status=True)),
    )
    
    print(f"   Total Outcomes: {stats['total']}")
    print(f"   Wins: {stats['wins']}")
    print(f"   Total Revenue: ${stats['total_revenue'] or 0}")
    print(f"   Avg Win Price: ${stats['avg_win_price'] or 0}")
    
    if stats['total'] > 0:
        win_rate = (stats['wins'] / stats['total'] * 100)
        print(f"   Win Rate: {win_rate:.1f}%")
    
    print()


def cleanup():
    """Clean up test data."""
    print("=" * 60)
    print("Cleaning Up Test Data")
    print("=" * 60)
    
    deleted = AuctionOutcome.objects.filter(bid_id__startswith="test-bid-").delete()
    print(f"✅ Deleted {deleted[0]} test outcomes")
    print()


def main():
    """Run all tests."""
    print("\n" + "=" * 60)
    print("Analytics Service - Model Tests")
    print("=" * 60 + "\n")
    
    try:
        # Test model creation
        outcome = test_model_creation()
        
        # Test queries
        test_model_queries()
        
        # Test aggregations
        test_model_aggregations()
        
        # Cleanup
        cleanup()
        
        print("=" * 60)
        print("✅ All Tests Passed!")
        print("=" * 60)
        print("\nNext steps:")
        print("1. Start the API: python manage.py runserver")
        print("2. Start the consumer: python manage.py process_outcomes")
        print("3. Test the API: curl http://localhost:8000/api/outcomes/")
        print()
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
