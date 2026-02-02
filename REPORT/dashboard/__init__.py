"""
Performance Dashboard Package

A web-based dashboard for visualizing and analyzing performance benchmark reports.
"""

from .dashboard_app import DashboardApp, create_app
from .data_loader import ReportLoader, ReportFilter, BenchmarkResult
from .aggregator import BenchmarkAggregator

__version__ = '1.0.0'

__all__ = [
    'DashboardApp',
    'create_app',
    'ReportLoader',
    'ReportFilter',
    'BenchmarkResult',
    'BenchmarkAggregator'
]
