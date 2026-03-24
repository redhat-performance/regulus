"""
Comparison routes - Configuration comparisons and comparison matrices.
"""

from flask import Blueprint, request, jsonify

comparison_bp = Blueprint('comparison', __name__, url_prefix='/api')


def init_comparison_routes(data_service, comparison_service, aggregation_service):
    """Initialize comparison routes with service dependencies."""

    @comparison_bp.route('/compare')
    def api_compare():
        """Compare two configurations."""
        if not aggregation_service.aggregator:
            return jsonify({'error': 'No reports loaded'}), 404

        # Get comparison parameters
        field = request.args.get('field')  # e.g., 'model', 'kernel'
        value_a = request.args.get('value_a')
        value_b = request.args.get('value_b')
        metric = request.args.get('metric', 'mean')

        if not field or not value_a or not value_b:
            return jsonify({'error': 'Missing required parameters: field, value_a, value_b'}), 400

        # Get filter parameters
        filter_params = data_service.get_filter_params_from_request(request)

        # Perform comparison
        all_results = data_service.loader.extract_all_results()
        comparison = comparison_service.compare_configurations(
            all_results,
            field=field,
            value_a=value_a,
            value_b=value_b,
            metric=metric,
            filter_params=filter_params
        )

        if not comparison:
            return jsonify({'error': 'No data found for comparison'}), 404

        return jsonify(comparison)

    @comparison_bp.route('/matrix')
    def api_matrix():
        """Get configuration matrix."""
        if not aggregation_service.aggregator:
            return jsonify({'error': 'No reports loaded'}), 404

        field_x = request.args.get('field_x', 'model')
        field_y = request.args.get('field_y', 'kernel')
        metric = request.args.get('metric', 'mean')
        benchmark = request.args.get('benchmark')

        # Get configuration matrix from aggregator
        matrix = aggregation_service.aggregator.get_configuration_matrix(
            field_x=field_x,
            field_y=field_y,
            metric=metric,
            benchmark=benchmark
        )

        return jsonify(matrix)

    return comparison_bp
