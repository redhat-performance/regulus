"""
Admin routes - Administrative operations like reload.
"""

from flask import Blueprint, request, jsonify

admin_bp = Blueprint('admin', __name__, url_prefix='/api')


def init_admin_routes(loader, aggregator_callback):
    """
    Initialize admin routes with dependencies.

    Args:
        loader: ReportLoader instance
        aggregator_callback: Callable that recreates the aggregator after reload
    """

    @admin_bp.route('/reload', methods=['POST'])
    def api_reload():
        """Reload reports from disk."""
        try:
            reports_dir = request.json.get('reports_dir') if request.json else None
            if reports_dir:
                loader.reports_dir = reports_dir

            # Reload reports (clear existing data)
            loader.loaded_reports = []  # List, not dict
            loader.metadata = []         # Also clear metadata
            loader.load_from_directory(loader.reports_dir)
            results = loader.extract_all_results()

            # Recreate aggregator with new data
            aggregator_callback(results)

            return jsonify({
                'success': True,
                'total_reports': len(loader.loaded_reports),
                'total_results': len(results)
            })
        except Exception as e:
            import traceback
            return jsonify({
                'success': False,
                'error': str(e),
                'traceback': traceback.format_exc()
            }), 500

    return admin_bp
