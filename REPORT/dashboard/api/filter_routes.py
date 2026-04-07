"""
Filter routes - Filter options and dynamic cascading filters.
"""

from flask import Blueprint, request, jsonify
from ..data_loader import ReportFilter

filter_bp = Blueprint('filter', __name__, url_prefix='/api')


def init_filter_routes(data_service):
    """Initialize filter routes with service dependencies."""

    @filter_bp.route('/filters')
    def api_filters():
        """Get available filter options."""
        all_results = data_service.loader.extract_all_results()
        if not all_results:
            return jsonify({})

        filters = {}
        filter_fields = [
            'benchmark', 'model', 'nic', 'arch', 'protocol', 'test_type', 'cpu',
            'kernel', 'rcos', 'topo', 'perf', 'offload', 'threads',
            'pods_per_worker', 'scale_out_factor', 'wsize'
        ]

        for field in filter_fields:
            filters[field] = ReportFilter.get_unique_values(all_results, field)

        return jsonify(filters)

    @filter_bp.route('/comparison_values')
    def api_comparison_values():
        """Get available values for comparison field based on current filters."""
        all_results = data_service.loader.extract_all_results()
        if not all_results:
            return jsonify([])

        # Get the field we're comparing
        field = request.args.get('field')
        if not field:
            return jsonify([])

        # Get all filter parameters
        filter_params = data_service.get_filter_params_from_request(request)

        # Exclude the comparison field from filtering
        filter_params[field] = None

        # Get selected files filter
        selected_files_param = request.args.get('selected_files')
        selected_files = selected_files_param.split(',') if selected_files_param else None

        # Apply filters including date range
        filtered = data_service.apply_filters(
            all_results,
            filter_params,
            request.args.get('date_range_days'),
            selected_files
        )

        # Get unique values for the comparison field from filtered results
        values = ReportFilter.get_unique_values(filtered, field)

        return jsonify(values)

    @filter_bp.route('/dynamic_filters')
    def api_dynamic_filters():
        """Get available filter options based on current filter selections (cascading filters)."""
        all_results = data_service.loader.extract_all_results()
        if not all_results:
            return jsonify({})

        # Get all filter parameters
        filter_params = data_service.get_filter_params_from_request(request)

        # Get selected files filter
        selected_files_param = request.args.get('selected_files')
        selected_files = selected_files_param.split(',') if selected_files_param else None

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
            filtered = data_service.apply_filters(
                all_results,
                field_filter_params,
                request.args.get('date_range_days'),
                selected_files
            )

            # Get unique values for this field from the filtered results
            filters[field] = ReportFilter.get_unique_values(filtered, field)

        return jsonify(filters)

    return filter_bp
