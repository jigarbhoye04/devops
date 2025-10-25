"""
URL configuration for outcomes app.
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import AuctionOutcomeViewSet

# Create router and register viewsets
router = DefaultRouter()
router.register(r'outcomes', AuctionOutcomeViewSet, basename='auction-outcome')

urlpatterns = [
    path('', include(router.urls)),
]
