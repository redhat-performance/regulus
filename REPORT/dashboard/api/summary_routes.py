"""
Summary routes - Summary statistics and aggregations.
"""

from flask import Blueprint, request, jsonify

summary_bp = Blueprint('summary', __name__, url_prefix='/api')


def init_summary_routes(data_service, aggregation_service):
    """Initialize summary routes with service dependencies."""

    @summary_bp.route('/summary')
    def api_summary():
        """Get summary statistics with optional filtering."""
        if not aggregation_service.aggregator:
            return jsonify({'error': 'No reports loaded'}), 404

        # Get filter parameters from request
        filter_params = data_service.get_filter_params_from_request(request)

        # Apply filters including date range
        filtered = data_service.apply_filters(
            data_service.loader.extract_all_results(),
            filter_params,
            request.args.get('date_range_days')
        )

        # Calculate summary stats from filtered results
        summary = aggregation_service.get_summary(filtered)

        # Get benchmark summary from aggregator (unfiltered for now)
        benchmark_summary = aggregation_service.get_benchmark_summary()

        # Return in format expected by frontend JavaScript
        # Note: 'benchmarks' key used by frontend for benchmark summary data
        return jsonify({
            'reports': summary,
            'benchmarks': benchmark_summary
        })

    @summary_bp.route('/statistics')
    def api_statistics():
        """Get statistics grouped by a field."""
        if not aggregation_service.aggregator:
            return jsonify({'error': 'No reports loaded'}), 404

        # Get filter parameters
        filter_params = data_service.get_filter_params_from_request(request)

        # Apply filters
        all_results = data_service.loader.extract_all_results()
        filtered = data_service.apply_filters(
            all_results,
            filter_params,
            request.args.get('date_range_days')
        )

        # Get statistics parameters
        group_by = request.args.get('group_by', 'model')
        metric = request.args.get('metric', 'mean')
        unit_filter = request.args.get('unit_filter')  # Filter by unit (e.g., 'Gbps')

        # Create aggregator with filtered results
        from aggregator import BenchmarkAggregator
        temp_aggregator = BenchmarkAggregator(filtered)
        stats = temp_aggregator.get_statistics_by_group(
            group_by=group_by,
            metric=metric,
            benchmark=None,  # Already filtered above
            unit_filter=unit_filter
        )

        return jsonify(stats)

    return summary_bp
