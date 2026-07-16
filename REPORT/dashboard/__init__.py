"""
Performance Dashboard Package

A web-based dashboard for visualizing and analyzing performance benchmark reports.

The dashboard uses a modular architecture with Flask application factory pattern.
"""

# Core data handling classes (no Flask dependency)
from .data_loader import ReportLoader, ReportFilter, BenchmarkResult
from .aggregator import BenchmarkAggregator

__version__ = '1.1.0'


def create_app(*args, **kwargs):
    """Lazy wrapper so Flask is only imported when the dashboard is actually started."""
    from .app import create_app as _create_app
    return _create_app(*args, **kwargs)


__all__ = [
    'create_app',
    'ReportLoader',
    'ReportFilter',
    'BenchmarkResult',
    'BenchmarkAggregator'
]
