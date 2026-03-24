"""
Services package for dashboard business logic.

This package contains pure business logic classes with no Flask dependencies,
making them testable and reusable.
"""

from .data_service import DataService
from .aggregation_service import AggregationService
from .comparison_service import ComparisonService
from .trend_service import TrendService

__all__ = [
    'DataService',
    'AggregationService',
    'ComparisonService',
    'TrendService'
]
