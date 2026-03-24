"""
Trend routes - Time-series analysis.
"""

from flask import Blueprint, request, jsonify

trend_bp = Blueprint('trend', __name__, url_prefix='/api')


def init_trend_routes(data_service, trend_service):
    """Initialize trend routes with service dependencies."""

    @trend_bp.route('/trends')
    def api_trends():
        """Get trend data over time."""
        # Get filter parameters
        filter_params = data_service.get_filter_params_from_request(request)

        # Apply filters including date range
        all_results = data_service.loader.extract_all_results()
        filtered = data_service.apply_filters(
            all_results,
            filter_params,
            request.args.get('date_range_days')
        )

        # Get trends parameters
        metric = request.args.get('metric', 'mean')
        group_by = request.args.get('group_by')  # e.g., 'model', 'kernel'
        unit_filter = request.args.get('unit_filter')  # Filter by unit (e.g., 'Gbps')

        # Get trends from service
        trends_data = trend_service.get_trends(
            filtered,
            metric=metric,
            group_by=group_by,
            unit_filter=unit_filter
        )

        return jsonify(trends_data)

    return trend_bp
