"""
Performance Dashboard Package

A web-based dashboard for visualizing and analyzing performance benchmark reports.

The dashboard now uses a modular architecture:
- create_app(): New Flask application factory (preferred for new code)
- DashboardApp: Legacy class-based app (maintained for backward compatibility)
"""

# New modular architecture (preferred)
from .app import create_app

# Legacy class-based app (backward compatibility)
from .dashboard_app import DashboardApp

# Core data handling classes
from .data_loader import ReportLoader, ReportFilter, BenchmarkResult
from .aggregator import BenchmarkAggregator

__version__ = '1.0.0'

__all__ = [
    'create_app',
    'DashboardApp',
    'ReportLoader',
    'ReportFilter',
    'BenchmarkResult',
    'BenchmarkAggregator'
]
