"""
API blueprints package for dashboard routes.

This package contains Flask blueprints that organize routes into logical modules.
"""

from .summary_routes import summary_bp
from .results_routes import results_bp
from .trend_routes import trend_bp
from .comparison_routes import comparison_bp
from .filter_routes import filter_bp
from .admin_routes import admin_bp

__all__ = [
    'summary_bp',
    'results_bp',
    'trend_bp',
    'comparison_bp',
    'filter_bp',
    'admin_bp'
]
