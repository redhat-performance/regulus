"""
Dashboard web application.

Flask-based web server providing REST API endpoints and serving
the interactive dashboard frontend.
"""

from flask import Flask, jsonify, request, render_template, send_from_directory
from pathlib import Path
from typing import Dict, Any, List, Optional
import json
import os

try:
    from .data_loader import ReportLoader, ReportFilter, BenchmarkResult
    from .aggregator import BenchmarkAggregator
except ImportError:
    from data_loader import ReportLoader, ReportFilter, BenchmarkResult
    from aggregator import BenchmarkAggregator


class DashboardApp:
    """Performance Dashboard Web Application."""

    def __init__(self, reports_dir: Optional[str] = None, host: str = '0.0.0.0', port: int = 5000):
        # Get absolute paths for templates and static folders
        dashboard_dir = Path(__file__).resolve().parent
        template_dir = dashboard_dir / 'templates'
        static_dir = dashboard_dir / 'static'

        # Verify directories exist
        if not template_dir.exists():
            raise RuntimeError(f"Templates directory not found: {template_dir}")
        if not static_dir.exists():
            raise RuntimeError(f"Static directory not found: {static_dir}")

        self.app = Flask(
            __name__,
            template_folder=str(template_dir),
            static_folder=str(static_dir)
        )
        self.host = host
        self.port = port
        self.reports_dir = reports_dir or '.'

        self.loader = ReportLoader()
        self.results: List[BenchmarkResult] = []
        self.aggregator: Optional[BenchmarkAggregator] = None

        self._setup_routes()

    def load_reports(self, reports_dir: Optional[str] = None):
        """Load all JSON reports from the specified directory."""
        if reports_dir:
            self.reports_dir = reports_dir

        # Clear existing reports before loading new ones
        self.loader.loaded_reports.clear()
        self.loader.metadata.clear()

        print(f"Loading reports from: {self.reports_dir}")
        self.loader.load_from_directory(self.reports_dir)
        self.results = self.loader.extract_all_results()
        self.aggregator = BenchmarkAggregator(self.results)
        print(f"Loaded {len(self.results)} benchmark results from {len(self.loader.loaded_reports)} reports")

    def _apply_filters(self, results: List[BenchmarkResult], filter_params: Dict[str, Any], date_range_days: Optional[str] = None) -> List[BenchmarkResult]:
        """Apply filters to results including date range filtering."""
        filtered = results

        # Apply date range filter first if specified
        if date_range_days:
            try:
                days = int(date_range_days)
                filtered = ReportFilter.filter_by_days_ago(filtered, days)
            except ValueError:
                pass  # Ignore invalid date range values

        # Apply other filters
        for field, value in filter_params.items():
            if value:
                if field == 'benchmark':
                    filtered = ReportFilter.filter_by_benchmark(filtered, value)
                else:
                    filtered = ReportFilter.filter_by_tag(filtered, field, value)

        return filtered

    def _setup_routes(self):
        """Setup Flask routes."""

        @self.app.route('/')
        def index():
            """Serve the main dashboard page."""
            return render_template('dashboard.html')

        @self.app.route('/api/summary')
        def api_summary():
            """Get summary statistics with optional filtering."""
            if not self.aggregator:
                return jsonify({'error': 'No reports loaded'}), 404

            # Get filter parameters
            filter_params = {
                'benchmark': request.args.get('benchmark'),
                'model': request.args.get('model'),
                'nic': request.args.get('nic'),
                'arch': request.args.get('arch'),
                'protocol': request.args.get('protocol'),
                'test_type': request.args.get('test_type'),
                'cpu': request.args.get('cpu'),
                'kernel': request.args.get('kernel'),
                'rcos': request.args.get('rcos'),
                'topo': request.args.get('topo'),
                'perf': request.args.get('perf'),
                'offload': request.args.get('offload'),
                'threads': request.args.get('threads'),
                'pods_per_worker': request.args.get('pods_per_worker'),
                'scale_out_factor': request.args.get('scale_out_factor'),
                'wsize': request.args.get('wsize')
            }

            # Apply filters including date range
            filtered = self._apply_filters(
                self.results,
                filter_params,
                request.args.get('date_range_days')
            )

            # Calculate summary stats from filtered results
            # Count unique report.json files (not result-summary files)
            unique_reports = set()
            unique_benchmarks = set()
            for r in filtered:
                if r.report_source:
                    unique_reports.add(r.report_source)
                if r.benchmark:
                    unique_benchmarks.add(r.benchmark)

            # Get date range from filtered results
            timestamps = [r.timestamp for r in filtered if r.timestamp]
            date_range = None
            if timestamps:
                sorted_ts = sorted(timestamps)
                date_range = {
                    'earliest': sorted_ts[0],
                    'latest': sorted_ts[-1]
                }

            summary = {
                'total_reports': len(unique_reports),
                'total_iterations': len(filtered),
                'benchmarks': sorted(list(unique_benchmarks)),
                'date_range': date_range
            }

            # Get benchmark summary from aggregator (unfiltered for now)
            benchmark_summary = self.aggregator.get_benchmark_summary()

            return jsonify({
                'reports': summary,
                'benchmarks': benchmark_summary
            })

        @self.app.route('/api/results')
        def api_results():
            """Get all benchmark results with optional filtering."""
            if not self.results:
                return jsonify([])

            # Get all filter parameters
            filter_params = {
                'benchmark': request.args.get('benchmark'),
                'model': request.args.get('model'),
                'nic': request.args.get('nic'),
                'arch': request.args.get('arch'),
                'protocol': request.args.get('protocol'),
                'test_type': request.args.get('test_type'),
                'cpu': request.args.get('cpu'),
                'kernel': request.args.get('kernel'),
                'rcos': request.args.get('rcos'),
                'topo': request.args.get('topo'),
                'perf': request.args.get('perf'),
                'offload': request.args.get('offload'),
                'threads': request.args.get('threads'),
                'pods_per_worker': request.args.get('pods_per_worker'),
                'scale_out_factor': request.args.get('scale_out_factor'),
                'wsize': request.args.get('wsize')
            }

            # Apply filters including date range
            filtered = self._apply_filters(
                self.results,
                filter_params,
                request.args.get('date_range_days')
            )

            # Convert to dict for JSON serialization
            results_data = [self._result_to_dict(r) for r in filtered]

            return jsonify(results_data)

        @self.app.route('/api/trends')
        def api_trends():
            """Get trend data over time."""
            if not self.aggregator:
                return jsonify({'error': 'No reports loaded'}), 404

            # Apply filters first
            filter_params = {
                'benchmark': request.args.get('benchmark'),
                'model': request.args.get('model'),
                'nic': request.args.get('nic'),
                'arch': request.args.get('arch'),
                'protocol': request.args.get('protocol'),
                'test_type': request.args.get('test_type'),
                'cpu': request.args.get('cpu'),
                'kernel': request.args.get('kernel'),
                'rcos': request.args.get('rcos'),
                'topo': request.args.get('topo'),
                'perf': request.args.get('perf'),
                'offload': request.args.get('offload'),
                'threads': request.args.get('threads'),
                'pods_per_worker': request.args.get('pods_per_worker'),
                'scale_out_factor': request.args.get('scale_out_factor'),
                'wsize': request.args.get('wsize')
            }

            # Apply filters including date range
            filtered = self._apply_filters(
                self.results,
                filter_params,
                request.args.get('date_range_days')
            )

            # Get trends parameters
            metric = request.args.get('metric', 'mean')
            group_by = request.args.get('group_by')  # e.g., 'model', 'kernel'
            unit_filter = request.args.get('unit_filter')  # Filter by unit (e.g., 'Gbps')

            # Create aggregator with filtered results
            temp_aggregator = BenchmarkAggregator(filtered)
            trends = temp_aggregator.get_trend_over_time(
                metric=metric,
                group_by=group_by,
                benchmark=None,  # Already filtered above
                unit_filter=unit_filter
            )

            # Convert to JSON-serializable format
            trends_data = {}
            for group_key, data_points in trends.items():
                trends_data[group_key] = [
                    {
                        'timestamp': dp.timestamp,
                        'mean': dp.mean,
                        'stddev': dp.stddev,
                        'count': dp.count,
                        'label': dp.label
                    }
                    for dp in data_points
                ]

            return jsonify(trends_data)

        @self.app.route('/api/compare')
        def api_compare():
            """Compare two configurations."""
            if not self.aggregator:
                return jsonify({'error': 'No reports loaded'}), 404

            # Apply filters first (excluding the comparison field itself)
            field = request.args.get('field')  # e.g., 'model', 'kernel'
            value_a = request.args.get('value_a')
            value_b = request.args.get('value_b')
            metric = request.args.get('metric', 'mean')

            if not field or not value_a or not value_b:
                return jsonify({'error': 'Missing required parameters: field, value_a, value_b'}), 400

            filter_params = {
                'benchmark': request.args.get('benchmark'),
                'model': request.args.get('model'),
                'nic': request.args.get('nic'),
                'arch': request.args.get('arch'),
                'protocol': request.args.get('protocol'),
                'test_type': request.args.get('test_type'),
                'cpu': request.args.get('cpu'),
                'kernel': request.args.get('kernel'),
                'rcos': request.args.get('rcos'),
                'topo': request.args.get('topo'),
                'perf': request.args.get('perf'),
                'offload': request.args.get('offload'),
                'threads': request.args.get('threads'),
                'pods_per_worker': request.args.get('pods_per_worker'),
                'scale_out_factor': request.args.get('scale_out_factor'),
                'wsize': request.args.get('wsize')
            }

            # Don't filter by the comparison field itself
            if field in filter_params:
                filter_params[field] = None

            filtered = self.results
            for filter_field, filter_value in filter_params.items():
                if filter_value:
                    if filter_field == 'benchmark':
                        filtered = ReportFilter.filter_by_benchmark(filtered, filter_value)
                    else:
                        filtered = ReportFilter.filter_by_tag(filtered, filter_field, filter_value)

            # Create aggregator with filtered results
            temp_aggregator = BenchmarkAggregator(filtered)
            comparison = temp_aggregator.compare_configurations(
                field=field,
                value_a=value_a,
                value_b=value_b,
                metric=metric,
                benchmark=None  # Already filtered above
            )

            if not comparison:
                return jsonify({'error': 'No data found for comparison'}), 404

            return jsonify({
                'config_a': comparison.config_a,
                'config_b': comparison.config_b,
                'metric': comparison.metric,
                'mean_a': comparison.mean_a,
                'mean_b': comparison.mean_b,
                'difference': comparison.difference,
                'percent_change': comparison.percent_change,
                'better': comparison.better
            })

        @self.app.route('/api/statistics')
        def api_statistics():
            """Get statistics grouped by a field."""
            if not self.aggregator:
                return jsonify({'error': 'No reports loaded'}), 404

            # Apply filters first
            filter_params = {
                'benchmark': request.args.get('benchmark'),
                'model': request.args.get('model'),
                'nic': request.args.get('nic'),
                'arch': request.args.get('arch'),
                'protocol': request.args.get('protocol'),
                'test_type': request.args.get('test_type'),
                'cpu': request.args.get('cpu'),
                'kernel': request.args.get('kernel'),
                'rcos': request.args.get('rcos'),
                'topo': request.args.get('topo'),
                'perf': request.args.get('perf'),
                'offload': request.args.get('offload'),
                'threads': request.args.get('threads'),
                'pods_per_worker': request.args.get('pods_per_worker'),
                'scale_out_factor': request.args.get('scale_out_factor'),
                'wsize': request.args.get('wsize')
            }

            # Apply filters including date range
            filtered = self._apply_filters(
                self.results,
                filter_params,
                request.args.get('date_range_days')
            )

            # Get statistics parameters
            group_by = request.args.get('group_by', 'model')
            metric = request.args.get('metric', 'mean')
            unit_filter = request.args.get('unit_filter')  # Filter by unit (e.g., 'Gbps')

            # Create aggregator with filtered results
            temp_aggregator = BenchmarkAggregator(filtered)
            stats = temp_aggregator.get_statistics_by_group(
                group_by=group_by,
                metric=metric,
                benchmark=None,  # Already filtered above
                unit_filter=unit_filter
            )

            return jsonify(stats)

        @self.app.route('/api/top_performers')
        def api_top_performers():
            """Get top performing results."""
            if not self.aggregator:
                return jsonify({'error': 'No reports loaded'}), 404

            # Apply filters first
            filter_params = {
                'benchmark': request.args.get('benchmark'),
                'model': request.args.get('model'),
                'nic': request.args.get('nic'),
                'arch': request.args.get('arch'),
                'protocol': request.args.get('protocol'),
                'test_type': request.args.get('test_type'),
                'cpu': request.args.get('cpu'),
                'kernel': request.args.get('kernel'),
                'rcos': request.args.get('rcos'),
                'topo': request.args.get('topo'),
                'perf': request.args.get('perf'),
                'offload': request.args.get('offload'),
                'threads': request.args.get('threads'),
                'pods_per_worker': request.args.get('pods_per_worker'),
                'scale_out_factor': request.args.get('scale_out_factor'),
                'wsize': request.args.get('wsize')
            }

            # Apply filters including date range
            filtered = self._apply_filters(
                self.results,
                filter_params,
                request.args.get('date_range_days')
            )

            metric = request.args.get('metric', 'mean')
            top_n = int(request.args.get('top_n', 10))
            ascending = request.args.get('ascending', 'false').lower() == 'true'
            unit_filter = request.args.get('unit_filter')  # Filter by unit (e.g., 'Gbps')

            # Create aggregator with filtered results
            temp_aggregator = BenchmarkAggregator(filtered)
            top_results = temp_aggregator.get_top_performers(
                metric=metric,
                top_n=top_n,
                benchmark=None,  # Already filtered above
                ascending=ascending,
                unit_filter=unit_filter
            )

            results_data = [self._result_to_dict(r) for r in top_results]
            return jsonify(results_data)

        @self.app.route('/api/matrix')
        def api_matrix():
            """Get configuration matrix."""
            if not self.aggregator:
                return jsonify({'error': 'No reports loaded'}), 404

            field_x = request.args.get('field_x', 'model')
            field_y = request.args.get('field_y', 'kernel')
            metric = request.args.get('metric', 'mean')
            benchmark = request.args.get('benchmark')

            matrix = self.aggregator.get_configuration_matrix(
                field_x=field_x,
                field_y=field_y,
                metric=metric,
                benchmark=benchmark
            )

            return jsonify(matrix)

        @self.app.route('/api/filters')
        def api_filters():
            """Get available filter options."""
            if not self.results:
                return jsonify({})

            filters = {}
            filter_fields = [
                'benchmark', 'model', 'nic', 'arch', 'protocol', 'test_type', 'cpu',
                'kernel', 'rcos', 'topo', 'perf', 'offload', 'threads',
                'pods_per_worker', 'scale_out_factor', 'wsize'
            ]

            for field in filter_fields:
                filters[field] = ReportFilter.get_unique_values(self.results, field)

            return jsonify(filters)

        @self.app.route('/api/comparison_values')
        def api_comparison_values():
            """Get available values for comparison field based on current filters."""
            if not self.results:
                return jsonify([])

            # Get the field we're comparing
            field = request.args.get('field')
            if not field:
                return jsonify([])

            # Get all filter parameters
            filter_params = {
                'benchmark': request.args.get('benchmark'),
                'model': request.args.get('model'),
                'nic': request.args.get('nic'),
                'arch': request.args.get('arch'),
                'protocol': request.args.get('protocol'),
                'test_type': request.args.get('test_type'),
                'cpu': request.args.get('cpu'),
                'kernel': request.args.get('kernel'),
                'rcos': request.args.get('rcos'),
                'topo': request.args.get('topo'),
                'perf': request.args.get('perf'),
                'offload': request.args.get('offload'),
                'threads': request.args.get('threads'),
                'pods_per_worker': request.args.get('pods_per_worker'),
                'scale_out_factor': request.args.get('scale_out_factor'),
                'wsize': request.args.get('wsize')
            }

            # Exclude the comparison field from filtering
            filter_params[field] = None

            # Apply filters including date range
            filtered = self._apply_filters(
                self.results,
                filter_params,
                request.args.get('date_range_days')
            )

            # Get unique values for the comparison field from filtered results
            values = ReportFilter.get_unique_values(filtered, field)

            return jsonify(values)

        @self.app.route('/api/dynamic_filters')
        def api_dynamic_filters():
            """Get available filter options based on current filter selections (cascading filters)."""
            if not self.results:
                return jsonify({})

            # Get all filter parameters
            filter_params = {
                'benchmark': request.args.get('benchmark'),
                'model': request.args.get('model'),
                'nic': request.args.get('nic'),
                'arch': request.args.get('arch'),
                'protocol': request.args.get('protocol'),
                'test_type': request.args.get('test_type'),
                'cpu': request.args.get('cpu'),
                'kernel': request.args.get('kernel'),
                'rcos': request.args.get('rcos'),
                'topo': request.args.get('topo'),
                'perf': request.args.get('perf'),
                'offload': request.args.get('offload'),
                'threads': request.args.get('threads'),
                'pods_per_worker': request.args.get('pods_per_worker'),
                'scale_out_factor': request.args.get('scale_out_factor'),
                'wsize': request.args.get('wsize')
            }

            # Get unique values for each filter field from filtered results
            # IMPORTANT: For each field, exclude that field from filtering so users can change their selection
            filter_fields = [
                'benchmark', 'model', 'nic', 'arch', 'protocol', 'test_type', 'cpu',
                'kernel', 'rcos', 'topo', 'perf', 'offload', 'threads',
                'pods_per_worker', 'scale_out_factor', 'wsize'
            ]

            filters = {}
            for field in filter_fields:
                # Create a copy of filter_params excluding the current field
                field_filter_params = {k: v for k, v in filter_params.items() if k != field}

                # Apply filters (excluding the current field)
                filtered = self._apply_filters(
                    self.results,
                    field_filter_params,
                    request.args.get('date_range_days')
                )

                # Get unique values for this field from the filtered results
                filters[field] = ReportFilter.get_unique_values(filtered, field)

            return jsonify(filters)

        @self.app.route('/api/reload', methods=['POST'])
        def api_reload():
            """Reload reports from disk."""
            try:
                reports_dir = request.json.get('reports_dir') if request.json else None
                self.load_reports(reports_dir)
                return jsonify({'status': 'success', 'message': f'Loaded {len(self.results)} results'})
            except Exception as e:
                return jsonify({'status': 'error', 'message': str(e)}), 500

    def _result_to_dict(self, result: BenchmarkResult) -> Dict[str, Any]:
        """Convert BenchmarkResult to dictionary for JSON serialization."""
        return {
            'regulus_data': result.regulus_data,
            'benchmark': result.benchmark,
            'iteration_id': result.iteration_id,
            'test_type': result.test_type,
            'protocol': result.protocol,
            'model': result.model,      # Datapath model (OVNK, DPU, etc.)
            'nic': result.nic,          # NIC vendor (e810, e910, cx5, cx7, etc.)
            'arch': result.arch,        # CPU architecture (emerald_rapid, sapphire_rapids, etc.)
            'perf': result.perf,
            'offload': result.offload,
            'kernel': result.kernel,
            'rcos': result.rcos,
            'cpu': result.cpu,
            'topo': result.topo,
            'pods_per_worker': result.pods_per_worker,
            'scale_out_factor': result.scale_out_factor,
            'threads': result.threads,
            'wsize': result.wsize,
            'rsize': result.rsize,
            'mean': result.mean,
            'min': result.min,
            'max': result.max,
            'stddev': result.stddev,
            'stddevpct': result.stddevpct,
            'unit': result.unit,
            'busy_cpu': result.busy_cpu,
            'samples_count': result.samples_count,
            'timestamp': result.timestamp,
            'run_id': result.run_id
        }

    def run(self, debug: bool = False):
        """Start the Flask development server."""
        print(f"\n{'='*60}")
        print(f"Starting Performance Dashboard")
        print(f"{'='*60}")
        print(f"Dashboard URL: http://{self.host}:{self.port}")
        print(f"Reports directory: {self.reports_dir}")
        print(f"Template directory: {self.app.template_folder}")
        print(f"Static directory: {self.app.static_folder}")
        print(f"Loaded reports: {len(self.loader.loaded_reports)}")
        print(f"Total results: {len(self.results)}")
        print(f"{'='*60}\n")

        self.app.run(host=self.host, port=self.port, debug=debug)


def create_app(reports_dir: Optional[str] = None, host: str = '0.0.0.0', port: int = 5000) -> DashboardApp:
    """
    Factory function to create and configure the dashboard app.

    Args:
        reports_dir: Directory containing JSON reports
        host: Host to bind to (default: 0.0.0.0)
        port: Port to listen on (default: 5000)

    Returns:
        Configured DashboardApp instance
    """
    app = DashboardApp(reports_dir=reports_dir, host=host, port=port)
    if reports_dir:
        app.load_reports(reports_dir)
    return app
