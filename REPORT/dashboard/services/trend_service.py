"""
Trend service for time-series analysis.

Pure business logic with no Flask dependencies.
"""

from typing import Dict, Any, Optional, List
from ..aggregator import BenchmarkAggregator


class TrendService:
    """Service for analyzing trends over time."""

    def get_trends(
        self,
        filtered_results: List,
        metric: str,
        group_by: Optional[str] = None,
        unit_filter: Optional[str] = None
    ) -> Dict[str, List[Dict[str, Any]]]:
        """
        Get trend data over time from filtered results.

        Args:
            filtered_results: Already filtered benchmark results
            metric: Metric to analyze ('mean', 'median', etc.)
            group_by: Optional field to group by (e.g., 'model', 'kernel')
            unit_filter: Optional unit filter (e.g., 'Gbps')

        Returns:
            Dictionary mapping group keys to lists of trend data points.
            Each data point contains: timestamp, mean, stddev, count, label
        """
        # Create aggregator with filtered results
        temp_aggregator = BenchmarkAggregator(filtered_results)
        trends = temp_aggregator.get_trend_over_time(
            metric=metric,
            group_by=group_by,
            benchmark=None,  # Already filtered
            unit_filter=unit_filter
        )

        # Convert to JSON-serializable format
        trends_data = {}
        for group_key, data_points in trends.items():
            trends_data[group_key] = [
                {
                    'timestamp': dp.timestamp,
                    'mean': dp.mean,
                    'stddev': dp.stddev,
                    'count': dp.count,
                    'label': dp.label
                }
                for dp in data_points
            ]

        return trends_data
