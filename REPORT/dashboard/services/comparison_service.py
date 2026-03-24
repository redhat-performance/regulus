"""
Comparison service for comparing configurations.

Pure business logic with no Flask dependencies.
"""

from typing import Dict, Any, Optional
from data_loader import ReportFilter
from aggregator import BenchmarkAggregator


class ComparisonService:
    """Service for comparing different configurations."""

    def compare_configurations(
        self,
        all_results,
        field: str,
        value_a: str,
        value_b: str,
        metric: str,
        filter_params: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        """
        Compare two configurations on a specific field.

        Args:
            all_results: All benchmark results
            field: Field to compare (e.g., 'model', 'kernel')
            value_a: First value to compare
            value_b: Second value to compare
            metric: Metric to use ('mean', 'median', etc.)
            filter_params: Other filters to apply (excluding comparison field)

        Returns:
            Dictionary with comparison results or None if no data found
        """
        # Don't filter by the comparison field itself
        if field in filter_params:
            filter_params[field] = None

        # Apply filters
        filtered = all_results
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
            return None

        return {
            'config_a': comparison.config_a,
            'config_b': comparison.config_b,
            'metric': comparison.metric,
            'mean_a': comparison.mean_a,
            'mean_b': comparison.mean_b,
            'difference': comparison.difference,
            'percent_change': comparison.percent_change,
            'better': comparison.better
        }
