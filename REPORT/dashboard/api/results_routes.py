"""
Results routes - Raw results and top performers.
"""

from flask import Blueprint, request, jsonify

results_bp = Blueprint('results', __name__, url_prefix='/api')


def init_results_routes(data_service, aggregation_service):
    """Initialize results routes with service dependencies."""

    @results_bp.route('/results')
    def api_results():
        """Get raw filtered results."""
        all_results = data_service.loader.extract_all_results()
        if not all_results:
            return jsonify({'error': 'No reports loaded'}), 404

        # Get filter parameters
        filter_params = data_service.get_filter_params_from_request(request)

        # Get selected files filter
        selected_files_param = request.args.get('selected_files')
        selected_files = selected_files_param.split(',') if selected_files_param else None

        # Apply filters
        filtered = data_service.apply_filters(
            all_results,
            filter_params,
            request.args.get('date_range_days'),
            selected_files
        )

        # Convert to JSON-serializable format
        results_data = [
            {
                'regulus_data': r.regulus_data,
                'benchmark': r.benchmark,
                'iteration_id': r.iteration_id,
                'test_type': r.test_type,
                'protocol': r.protocol,
                'model': r.model,
                'nic': r.nic,
                'arch': r.arch,
                'perf': r.perf,
                'offload': r.offload,
                'kernel': r.kernel,
                'rcos': r.rcos,
                'cpu': r.cpu,
                'topo': r.topo,
                'pods_per_worker': r.pods_per_worker,
                'scale_out_factor': r.scale_out_factor,
                'threads': r.threads,
                'wsize': r.wsize,
                'rsize': r.rsize,
                'mean': r.mean,
                'min': r.min,
                'max': r.max,
                'stddev': r.stddev,
                'stddevpct': r.stddevpct,
                'unit': r.unit,
                'busy_cpu': r.busy_cpu,
                'samples_count': r.samples_count,
                'timestamp': r.timestamp,
                'run_id': r.run_id
            }
            for r in filtered
        ]

        # Return just the array (matches original dashboard behavior)
        return jsonify(results_data)

    @results_bp.route('/top_performers')
    def api_top_performers():
        """Get top N performers for each benchmark."""
        if not aggregation_service.aggregator:
            return jsonify({'error': 'No reports loaded'}), 404

        # Get filter parameters
        filter_params = data_service.get_filter_params_from_request(request)
        limit = int(request.args.get('limit', 10))
        benchmark_filter = request.args.get('benchmark')

        # Get selected files filter
        selected_files_param = request.args.get('selected_files')
        selected_files = selected_files_param.split(',') if selected_files_param else None

        # Apply filters
        all_results = data_service.loader.extract_all_results()
        filtered = data_service.apply_filters(
            all_results,
            filter_params,
            request.args.get('date_range_days'),
            selected_files
        )

        # Create aggregator with filtered results
        from aggregator import BenchmarkAggregator
        temp_aggregator = BenchmarkAggregator(filtered)

        # Get benchmarks from summary
        summary = temp_aggregator.get_benchmark_summary()
        benchmarks = summary.get('benchmarks', {}).keys()

        # Get top performers per benchmark
        top_performers = {}
        for benchmark in benchmarks:
            top = temp_aggregator.get_top_performers(
                metric='mean',
                top_n=limit,
                benchmark=benchmark
            )
            if top:
                top_performers[benchmark] = [
                    {
                        'rank': i + 1,
                        'mean': r.mean,
                        'unit': r.unit,
                        'model': r.model,
                        'timestamp': r.timestamp,
                        'iteration_id': r.iteration_id
                    }
                    for i, r in enumerate(top)
                ]

        return jsonify(top_performers)

    return results_bp
