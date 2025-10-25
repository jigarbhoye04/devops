"""
Auction Outcome model for storing bid auction results.
"""

from django.db import models


class AuctionOutcome(models.Model):
    """
    Model representing the outcome of an auction for a bid.
    
    This model stores the final results of the RTB auction process,
    including whether a bid won and the final price.
    """
    
    bid_id = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Unique identifier for the bid request"
    )
    
    user_id = models.CharField(
        max_length=255,
        db_index=True,
        help_text="User identifier associated with the bid"
    )
    
    site_domain = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        db_index=True,
        help_text="Domain of the site where the ad would be displayed"
    )
    
    win_status = models.BooleanField(
        default=False,
        db_index=True,
        help_text="Whether the bid won the auction"
    )
    
    win_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Final price paid for the auction win (in USD)"
    )
    
    bid_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Original bid price submitted"
    )
    
    currency = models.CharField(
        max_length=3,
        default='USD',
        help_text="Currency code (ISO 4217)"
    )
    
    enriched = models.BooleanField(
        default=False,
        help_text="Whether the bid was enriched with user profile data"
    )
    
    timestamp = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
        help_text="Timestamp when the outcome was recorded"
    )
    
    auction_timestamp = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp when the auction was processed"
    )
    
    # Additional metadata
    user_interests = models.JSONField(
        default=list,
        blank=True,
        help_text="User interests from profile enrichment"
    )
    
    raw_data = models.JSONField(
        default=dict,
        blank=True,
        help_text="Raw auction outcome data from Kafka"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When this record was created in the database"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When this record was last updated"
    )
    
    class Meta:
        ordering = ['-timestamp']
        verbose_name = 'Auction Outcome'
        verbose_name_plural = 'Auction Outcomes'
        indexes = [
            models.Index(fields=['-timestamp']),
            models.Index(fields=['win_status', '-timestamp']),
            models.Index(fields=['user_id', '-timestamp']),
            models.Index(fields=['site_domain', '-timestamp']),
        ]
    
    def __str__(self):
        status = "WON" if self.win_status else "LOST"
        return f"{self.bid_id} - {status} - ${self.win_price}"
    
    def __repr__(self):
        return (
            f"<AuctionOutcome(bid_id='{self.bid_id}', "
            f"win_status={self.win_status}, "
            f"win_price={self.win_price})>"
        )
    
    @property
    def is_winner(self):
        """Check if this bid won the auction."""
        return self.win_status
    
    @property
    def profit_margin(self):
        """Calculate the difference between bid and win price."""
        if self.win_status:
            return float(self.bid_price - self.win_price)
        return 0.0
