"""
Performance Dashboard Package

A web-based dashboard for visualizing and analyzing performance benchmark reports.

The dashboard uses a modular architecture with Flask application factory pattern.
"""

# Modular architecture
from .app import create_app

# Core data handling classes
from .data_loader import ReportLoader, ReportFilter, BenchmarkResult
from .aggregator import BenchmarkAggregator

__version__ = '1.1.0'

__all__ = [
    'create_app',
    'ReportLoader',
    'ReportFilter',
    'BenchmarkResult',
    'BenchmarkAggregator'
]
