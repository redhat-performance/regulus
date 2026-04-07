"""
Data service for filtering and retrieving benchmark results.

Pure business logic with no Flask dependencies.
"""

from typing import List, Dict, Any, Optional
from flask import Request
from ..data_loader import BenchmarkResult, ReportFilter


class DataService:
    """Service for data filtering and retrieval operations."""

    def __init__(self, loader):
        """Initialize with a ReportLoader instance."""
        self.loader = loader

    def apply_filters(
        self,
        results: List[BenchmarkResult],
        filter_params: Dict[str, Any],
        date_range_days: Optional[str] = None,
        selected_files: Optional[List[str]] = None
    ) -> List[BenchmarkResult]:
        """
        Apply filters to results including date range and file filtering.

        Args:
            results: List of benchmark results to filter
            filter_params: Dictionary of field->value filters
            date_range_days: Optional days to filter by (e.g., '7', '30')
            selected_files: Optional list of report filenames to include

        Returns:
            Filtered list of benchmark results
        """
        filtered = results

        # Apply report file filter first if specified
        if selected_files:
            filtered = ReportFilter.filter_by_report_files(filtered, selected_files)

        # Apply date range filter if specified
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

    def get_filter_params_from_request(self, request: Request) -> Dict[str, Any]:
        """
        Extract filter parameters from Flask request object.

        Args:
            request: Flask request object

        Returns:
            Dictionary of filter parameters
        """
        return {
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
