"""
Admin configuration for Auction Outcomes.
"""

from django.contrib import admin
from .models import AuctionOutcome


@admin.register(AuctionOutcome)
class AuctionOutcomeAdmin(admin.ModelAdmin):
    """Admin interface for AuctionOutcome model."""
    
    list_display = [
        'bid_id',
        'user_id',
        'site_domain',
        'win_status',
        'win_price',
        'bid_price',
        'enriched',
        'timestamp',
    ]
    
    list_filter = [
        'win_status',
        'enriched',
        'currency',
        'timestamp',
    ]
    
    search_fields = [
        'bid_id',
        'user_id',
        'site_domain',
    ]
    
    readonly_fields = [
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
        'raw_data',
        'created_at',
        'updated_at',
    ]
    
    ordering = ['-timestamp']
    
    date_hierarchy = 'timestamp'
    
    def has_add_permission(self, request):
        """Disable adding outcomes through admin (data comes from Kafka)."""
        return False
    
    def has_delete_permission(self, request, obj=None):
        """Allow deletion for data cleanup."""
        return True
