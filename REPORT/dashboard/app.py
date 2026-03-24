"""
Flask application factory for the benchmark dashboard.

This module creates and configures the Flask app with all blueprints and services.
"""

import os
from flask import Flask, render_template
from data_loader import ReportLoader
from aggregator import BenchmarkAggregator

# Import services
from services.data_service import DataService
from services.aggregation_service import AggregationService
from services.comparison_service import ComparisonService
from services.trend_service import TrendService
from services.drill_down_service import DrillDownService

# Import blueprint initializers
from api.summary_routes import init_summary_routes
from api.results_routes import init_results_routes
from api.trend_routes import init_trend_routes
from api.comparison_routes import init_comparison_routes
from api.filter_routes import init_filter_routes
from api.admin_routes import init_admin_routes
from api.drill_down_routes import init_drill_down_routes


def create_app(reports_dir=None):
    """
    Create and configure the Flask application.

    Args:
        reports_dir: Directory containing benchmark reports (optional)

    Returns:
        Configured Flask application instance
    """
    app = Flask(__name__)

    # Determine reports directory
    if not reports_dir:
        reports_dir = os.environ.get('REPORTS_DIR', './test_data')

    # Initialize data loader and load reports
    print(f"Loading reports from: {reports_dir}")
    loader = ReportLoader()
    loader.reports_dir = reports_dir  # Save for reload functionality
    loader.load_from_directory(reports_dir)
    results = loader.extract_all_results()
    print(f"Loaded {len(results)} benchmark results from {len(loader.loaded_reports)} reports")

    # Initialize aggregator
    aggregator = BenchmarkAggregator(results)

    # Initialize services
    data_service = DataService(loader)
    aggregation_service = AggregationService(aggregator)
    comparison_service = ComparisonService()
    trend_service = TrendService()
    drill_down_service = DrillDownService()

    # Store references for admin reload
    app.aggregator = aggregator  # Store for access in routes

    def recreate_aggregator(new_results):
        """Callback to recreate aggregator after reload."""
        nonlocal aggregator
        aggregator = BenchmarkAggregator(new_results)
        aggregation_service.aggregator = aggregator
        app.aggregator = aggregator

    # Register main route
    @app.route('/')
    def index():
        """Serve the main dashboard page."""
        return render_template('dashboard.html')

    # Initialize and register blueprints
    summary_bp = init_summary_routes(data_service, aggregation_service)
    results_bp = init_results_routes(data_service, aggregation_service)
    trend_bp = init_trend_routes(data_service, trend_service)
    comparison_bp = init_comparison_routes(data_service, comparison_service, aggregation_service)
    filter_bp = init_filter_routes(data_service)
    admin_bp = init_admin_routes(loader, recreate_aggregator)
    drill_down_bp = init_drill_down_routes(drill_down_service)

    app.register_blueprint(summary_bp)
    app.register_blueprint(results_bp)
    app.register_blueprint(trend_bp)
    app.register_blueprint(comparison_bp)
    app.register_blueprint(filter_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(drill_down_bp)

    return app


if __name__ == '__main__':
    # For development - run directly
    app = create_app()
    app.run(host='0.0.0.0', port=5000, debug=True)
