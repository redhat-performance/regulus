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

    @admin_bp.route('/list_files', methods=['GET'])
    def api_list_files():
        """List all available report files with metadata."""
        try:
            files = []
            for idx, metadata in enumerate(loader.metadata):
                # Extract filename from path
                import os
                filename = os.path.basename(metadata.regulus_data)

                files.append({
                    'index': idx,
                    'filename': filename,
                    'path': metadata.regulus_data,
                    'total_results': metadata.total_results,
                    'total_iterations': metadata.total_iterations,
                    'benchmarks': metadata.benchmarks,
                    'timestamp': metadata.timestamp
                })

            return jsonify({
                'success': True,
                'files': files,
                'total_files': len(files)
            })
        except Exception as e:
            import traceback
            return jsonify({
                'success': False,
                'error': str(e),
                'traceback': traceback.format_exc()
            }), 500

    return admin_bp
