"""
Views for Auction Outcomes API.
"""

from rest_framework import viewsets, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Count, Sum, Avg, Q
from django.db.models.functions import TruncDate

from .models import AuctionOutcome
from .serializers import AuctionOutcomeSerializer, AuctionOutcomeSummarySerializer


class AuctionOutcomeViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for viewing auction outcomes.
    
    Provides read-only access to auction outcome data with filtering,
    ordering, and aggregation capabilities.
    
    Endpoints:
        GET /api/outcomes/ - List all outcomes
        GET /api/outcomes/{id}/ - Retrieve specific outcome
        GET /api/outcomes/stats/ - Get aggregated statistics
        GET /api/outcomes/winners/ - Get only winning outcomes
    """
    
    queryset = AuctionOutcome.objects.all()
    serializer_class = AuctionOutcomeSerializer
    filter_backends = [filters.OrderingFilter]
    ordering_fields = ['timestamp', 'win_price', 'bid_price', 'created_at']
    ordering = ['-timestamp']
    
    def get_serializer_class(self):
        """Use summary serializer for list view."""
        if self.action == 'list':
            return AuctionOutcomeSummarySerializer
        return AuctionOutcomeSerializer
    
    def get_queryset(self):
        """
        Optionally filter queryset based on query parameters.
        
        Query parameters:
            - user_id: Filter by user ID
            - site_domain: Filter by site domain
            - win_status: Filter by win status (true/false)
            - enriched: Filter by enrichment status (true/false)
            - min_price: Minimum win price
            - max_price: Maximum win price
        """
        queryset = AuctionOutcome.objects.all()
        
        # Filter by user_id
        user_id = self.request.query_params.get('user_id', None)
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        
        # Filter by site_domain
        site_domain = self.request.query_params.get('site_domain', None)
        if site_domain:
            queryset = queryset.filter(site_domain=site_domain)
        
        # Filter by win_status
        win_status = self.request.query_params.get('win_status', None)
        if win_status is not None:
            win_status_bool = win_status.lower() in ('true', '1', 'yes')
            queryset = queryset.filter(win_status=win_status_bool)
        
        # Filter by enriched status
        enriched = self.request.query_params.get('enriched', None)
        if enriched is not None:
            enriched_bool = enriched.lower() in ('true', '1', 'yes')
            queryset = queryset.filter(enriched=enriched_bool)
        
        # Filter by price range
        min_price = self.request.query_params.get('min_price', None)
        if min_price:
            queryset = queryset.filter(win_price__gte=min_price)
        
        max_price = self.request.query_params.get('max_price', None)
        if max_price:
            queryset = queryset.filter(win_price__lte=max_price)
        
        return queryset
    
    @action(detail=False, methods=['get'])
    def stats(self, request):
        """
        Get aggregated statistics for auction outcomes.
        
        Returns:
            - total_outcomes: Total number of outcomes
            - total_wins: Number of winning bids
            - total_losses: Number of losing bids
            - win_rate: Percentage of wins
            - total_revenue: Sum of all win prices
            - average_win_price: Average price of winning bids
            - average_bid_price: Average bid price
            - enriched_count: Number of enriched outcomes
        """
        queryset = self.filter_queryset(self.get_queryset())
        
        stats = queryset.aggregate(
            total_outcomes=Count('id'),
            total_wins=Count('id', filter=Q(win_status=True)),
            total_losses=Count('id', filter=Q(win_status=False)),
            total_revenue=Sum('win_price', filter=Q(win_status=True)),
            average_win_price=Avg('win_price', filter=Q(win_status=True)),
            average_bid_price=Avg('bid_price'),
            enriched_count=Count('id', filter=Q(enriched=True)),
        )
        
        # Calculate win rate
        total = stats['total_outcomes'] or 0
        wins = stats['total_wins'] or 0
        stats['win_rate'] = round((wins / total * 100), 2) if total > 0 else 0.0
        
        # Convert Decimal to float for JSON serialization
        if stats['total_revenue']:
            stats['total_revenue'] = float(stats['total_revenue'])
        else:
            stats['total_revenue'] = 0.0
            
        if stats['average_win_price']:
            stats['average_win_price'] = float(stats['average_win_price'])
        else:
            stats['average_win_price'] = 0.0
            
        if stats['average_bid_price']:
            stats['average_bid_price'] = float(stats['average_bid_price'])
        else:
            stats['average_bid_price'] = 0.0
        
        return Response(stats)
    
    @action(detail=False, methods=['get'])
    def winners(self, request):
        """Get only winning auction outcomes."""
        queryset = self.filter_queryset(self.get_queryset())
        queryset = queryset.filter(win_status=True)
        
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = AuctionOutcomeSummarySerializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        
        serializer = AuctionOutcomeSummarySerializer(queryset, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def daily_stats(self, request):
        """Get daily aggregated statistics."""
        queryset = self.filter_queryset(self.get_queryset())
        
        daily_stats = (
            queryset
            .annotate(date=TruncDate('timestamp'))
            .values('date')
            .annotate(
                total=Count('id'),
                wins=Count('id', filter=Q(win_status=True)),
                revenue=Sum('win_price', filter=Q(win_status=True)),
                avg_win_price=Avg('win_price', filter=Q(win_status=True)),
            )
            .order_by('-date')
        )
        
        # Convert Decimal to float
        for stat in daily_stats:
            if stat['revenue']:
                stat['revenue'] = float(stat['revenue'])
            if stat['avg_win_price']:
                stat['avg_win_price'] = float(stat['avg_win_price'])
        
        return Response(list(daily_stats))
