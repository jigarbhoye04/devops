"""
Serializers for Auction Outcome API.
"""

from rest_framework import serializers
from .models import AuctionOutcome


class AuctionOutcomeSerializer(serializers.ModelSerializer):
    """
    Serializer for AuctionOutcome model.
    Provides read-only representation of auction outcomes.
    """
    
    is_winner = serializers.BooleanField(read_only=True)
    profit_margin = serializers.FloatField(read_only=True)
    
    class Meta:
        model = AuctionOutcome
        fields = [
            'id',
            'bid_id',
            'user_id',
            'site_domain',
            'win_status',
            'win_price',
            'bid_price',
            'currency',
            'enriched',
            'timestamp',
            'auction_timestamp',
            'user_interests',
            'is_winner',
            'profit_margin',
            'created_at',
            'updated_at',
        ]
        read_only_fields = fields  # All fields are read-only


class AuctionOutcomeSummarySerializer(serializers.ModelSerializer):
    """
    Minimal serializer for auction outcome listings.
    """
    
    class Meta:
        model = AuctionOutcome
        fields = [
            'id',
            'bid_id',
            'user_id',
            'win_status',
            'win_price',
            'timestamp',
        ]
        read_only_fields = fields
