"""
Aggregation service for calculating summaries and statistics.

Pure business logic with no Flask dependencies.
"""

from typing import List, Dict, Any


class AggregationService:
    """Service for aggregating benchmark data and calculating statistics."""

    def __init__(self, aggregator):
        """Initialize with a BenchmarkAggregator instance."""
        self.aggregator = aggregator

    def get_summary(self, filtered_results: List) -> Dict[str, Any]:
        """
        Calculate summary statistics from filtered results.

        Args:
            filtered_results: List of filtered BenchmarkResult objects

        Returns:
            Dictionary with summary statistics including:
            - total_reports: Number of unique report files
            - total_iterations: Number of test iterations
            - benchmarks: List of benchmark names
            - date_range: Earliest and latest timestamps
        """
        # Count unique report.json files (not result-summary files)
        unique_reports = set()
        unique_benchmarks = set()
        for r in filtered_results:
            if r.report_source:
                unique_reports.add(r.report_source)
            if r.benchmark:
                unique_benchmarks.add(r.benchmark)

        # Get date range from filtered results
        timestamps = [r.timestamp for r in filtered_results if r.timestamp]
        date_range = None
        if timestamps:
            sorted_ts = sorted(timestamps)
            date_range = {
                'earliest': sorted_ts[0],
                'latest': sorted_ts[-1]
            }

        return {
            'total_reports': len(unique_reports),
            'total_iterations': len(filtered_results),
            'benchmarks': sorted(list(unique_benchmarks)),
            'date_range': date_range
        }

    def get_benchmark_summary(self) -> Dict[str, Any]:
        """
        Get benchmark summary from aggregator.

        Returns:
            Dictionary mapping benchmark names to their statistics
        """
        return self.aggregator.get_benchmark_summary()
