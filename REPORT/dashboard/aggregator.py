"""
Aggregator for multi-report analytics.

Provides trend analysis, comparisons, and statistical aggregations
across multiple performance benchmark reports.
"""

from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from collections import defaultdict
from datetime import datetime
import statistics

try:
    from .data_loader import BenchmarkResult
except ImportError:
    from data_loader import BenchmarkResult


@dataclass
class TrendDataPoint:
    """Single data point in a trend series."""
    timestamp: str
    mean: float
    stddev: Optional[float] = None
    count: int = 1
    label: Optional[str] = None


@dataclass
class ComparisonResult:
    """Result of comparing two configurations."""
    config_a: str
    config_b: str
    metric: str
    mean_a: float
    mean_b: float
    difference: float
    percent_change: float
    better: str  # "config_a", "config_b", or "equal"


class BenchmarkAggregator:
    """Aggregates and analyzes benchmark results across multiple reports."""

    def __init__(self, results: List[BenchmarkResult]):
        self.results = results

    def get_trend_over_time(
        self,
        metric: str = 'mean',
        group_by: Optional[str] = None,
        benchmark: Optional[str] = None,
        unit_filter: Optional[str] = None
    ) -> Dict[str, List[TrendDataPoint]]:
        """
        Get performance trends over time.

        Args:
            metric: Metric to track (mean, max, min, etc.)
            group_by: Group results by this field (model, kernel, etc.)
            benchmark: Filter to specific benchmark type
            unit_filter: Filter to specific unit (e.g., 'Gbps' to include Gbps, tx-Gbps, rx-Gbps)

        Returns:
            Dictionary mapping group values to trend data points
        """
        # Filter by benchmark if specified
        filtered = self.results
        if benchmark:
            filtered = [r for r in filtered if r.benchmark == benchmark]

        # Filter by unit if specified (allows partial match like 'Gbps' matches 'tx-Gbps', 'rx-Gbps')
        if unit_filter:
            filtered = [r for r in filtered if r.unit and unit_filter in r.unit]

        # Group results
        groups = defaultdict(list)

        for result in filtered:
            # Determine group key
            if group_by:
                group_key = getattr(result, group_by, 'unknown')
                if group_key is None:
                    group_key = 'unknown'
            else:
                group_key = 'all'

            metric_value = getattr(result, metric, None)
            if metric_value is not None and result.timestamp:
                groups[str(group_key)].append(result)

        # Create trend data points for each group
        trends = {}
        for group_key, group_results in groups.items():
            # Sort by timestamp
            sorted_results = sorted(
                group_results,
                key=lambda r: r.timestamp if r.timestamp else ''
            )

            # Aggregate by timestamp (in case multiple results have same timestamp)
            timestamp_groups = defaultdict(list)
            for result in sorted_results:
                timestamp_groups[result.timestamp].append(getattr(result, metric))

            # Create data points
            data_points = []
            for ts in sorted(timestamp_groups.keys()):
                values = timestamp_groups[ts]
                data_point = TrendDataPoint(
                    timestamp=ts,
                    mean=statistics.mean(values),
                    stddev=statistics.stdev(values) if len(values) > 1 else None,
                    count=len(values),
                    label=group_key
                )
                data_points.append(data_point)

            trends[group_key] = data_points

        return trends

    def compare_configurations(
        self,
        field: str,
        value_a: str,
        value_b: str,
        metric: str = 'mean',
        benchmark: Optional[str] = None
    ) -> Optional[ComparisonResult]:
        """
        Compare two configurations.

        Args:
            field: Field to compare (model, kernel, perf, etc.)
            value_a: First value to compare
            value_b: Second value to compare
            metric: Metric to compare (mean, max, etc.)
            benchmark: Filter to specific benchmark

        Returns:
            ComparisonResult with the comparison data
        """
        # Filter results
        filtered = self.results
        if benchmark:
            filtered = [r for r in filtered if r.benchmark == benchmark]

        # Integer fields that need type conversion
        int_fields = {'threads', 'wsize', 'rsize'}

        # Convert values to appropriate type for comparison
        if field in int_fields:
            try:
                comp_value_a = int(value_a)
                comp_value_b = int(value_b)
            except (ValueError, TypeError):
                return None
        else:
            comp_value_a = value_a
            comp_value_b = value_b

        # Get results for each configuration
        results_a = [r for r in filtered if getattr(r, field, None) == comp_value_a]
        results_b = [r for r in filtered if getattr(r, field, None) == comp_value_b]

        if not results_a or not results_b:
            return None

        # Calculate means
        values_a = [getattr(r, metric) for r in results_a if getattr(r, metric, None) is not None]
        values_b = [getattr(r, metric) for r in results_b if getattr(r, metric, None) is not None]

        if not values_a or not values_b:
            return None

        mean_a = statistics.mean(values_a)
        mean_b = statistics.mean(values_b)

        difference = mean_b - mean_a
        percent_change = (difference / mean_a * 100) if mean_a != 0 else 0

        # Determine which is better (higher is better for throughput)
        if abs(percent_change) < 1:
            better = "equal"
        elif mean_b > mean_a:
            better = "config_b"
        else:
            better = "config_a"

        return ComparisonResult(
            config_a=f"{field}={value_a}",
            config_b=f"{field}={value_b}",
            metric=metric,
            mean_a=mean_a,
            mean_b=mean_b,
            difference=difference,
            percent_change=percent_change,
            better=better
        )

    def get_statistics_by_group(
        self,
        group_by: str,
        metric: str = 'mean',
        benchmark: Optional[str] = None,
        unit_filter: Optional[str] = None
    ) -> Dict[str, Dict[str, float]]:
        """
        Get statistical summary grouped by a field.

        Args:
            group_by: Field to group by (model, kernel, topo, etc.)
            metric: Metric to analyze
            benchmark: Filter to specific benchmark
            unit_filter: Filter to specific unit (e.g., 'Gbps' to include Gbps, tx-Gbps, rx-Gbps)

        Returns:
            Dictionary mapping group values to statistics (mean, median, stddev, min, max, count)
        """
        # Filter by benchmark if specified
        filtered = self.results
        if benchmark:
            filtered = [r for r in filtered if r.benchmark == benchmark]

        # Filter by unit if specified (allows partial match like 'Gbps' matches 'tx-Gbps', 'rx-Gbps')
        if unit_filter:
            filtered = [r for r in filtered if r.unit and unit_filter in r.unit]

        # Group results
        groups = defaultdict(list)
        for result in filtered:
            group_key = getattr(result, group_by, 'unknown')
            if group_key is None:
                group_key = 'unknown'

            metric_value = getattr(result, metric, None)
            if metric_value is not None:
                groups[str(group_key)].append(metric_value)

        # Calculate statistics for each group
        stats = {}
        for group_key, values in groups.items():
            if values:
                stats[group_key] = {
                    'mean': statistics.mean(values),
                    'median': statistics.median(values),
                    'stddev': statistics.stdev(values) if len(values) > 1 else 0,
                    'min': min(values),
                    'max': max(values),
                    'count': len(values)
                }

        return stats

    def get_top_performers(
        self,
        metric: str = 'mean',
        top_n: int = 10,
        benchmark: Optional[str] = None,
        ascending: bool = False,
        unit_filter: Optional[str] = None
    ) -> List[BenchmarkResult]:
        """
        Get top performing results.

        Args:
            metric: Metric to rank by
            top_n: Number of top results to return
            benchmark: Filter to specific benchmark
            ascending: If True, return lowest values (for latency); if False, highest (for throughput)
            unit_filter: Filter to specific unit (e.g., 'Gbps' to include Gbps, tx-Gbps, rx-Gbps)

        Returns:
            List of top performing benchmark results
        """
        # Filter by benchmark if specified
        filtered = self.results
        if benchmark:
            filtered = [r for r in filtered if r.benchmark == benchmark]

        # Filter by unit if specified
        if unit_filter:
            filtered = [r for r in filtered if r.unit and unit_filter in r.unit]

        # Filter out results without the metric
        valid_results = [r for r in filtered if getattr(r, metric, None) is not None]

        # Sort by metric
        sorted_results = sorted(
            valid_results,
            key=lambda r: getattr(r, metric),
            reverse=not ascending
        )

        return sorted_results[:top_n]

    def get_configuration_matrix(
        self,
        field_x: str,
        field_y: str,
        metric: str = 'mean',
        benchmark: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Create a matrix of performance across two configuration dimensions.

        Args:
            field_x: Field for X-axis (e.g., 'model')
            field_y: Field for Y-axis (e.g., 'kernel')
            metric: Metric to display
            benchmark: Filter to specific benchmark

        Returns:
            Dictionary with x_labels, y_labels, and matrix data
        """
        # Filter by benchmark if specified
        filtered = self.results
        if benchmark:
            filtered = [r for r in filtered if r.benchmark == benchmark]

        # Get unique values for each dimension
        x_values = sorted(set(str(getattr(r, field_x, 'unknown')) for r in filtered))
        y_values = sorted(set(str(getattr(r, field_y, 'unknown')) for r in filtered))

        # Build matrix
        matrix = {}
        for y_val in y_values:
            matrix[y_val] = {}
            for x_val in x_values:
                # Find matching results
                matching = [
                    r for r in filtered
                    if str(getattr(r, field_x, 'unknown')) == x_val
                    and str(getattr(r, field_y, 'unknown')) == y_val
                ]

                # Calculate average metric
                values = [getattr(r, metric) for r in matching if getattr(r, metric, None) is not None]
                matrix[y_val][x_val] = statistics.mean(values) if values else None

        return {
            'x_labels': x_values,
            'y_labels': y_values,
            'x_field': field_x,
            'y_field': field_y,
            'matrix': matrix,
            'metric': metric
        }

    def get_benchmark_summary(self) -> Dict[str, Any]:
        """
        Get overall summary of all benchmark results.

        Returns:
            Summary statistics and counts
        """
        if not self.results:
            return {
                'total_results': 0,
                'benchmarks': {},
                'tags': {},
                'metric_ranges': {}
            }

        # Count by benchmark
        benchmark_counts = defaultdict(int)
        for r in self.results:
            benchmark_counts[r.benchmark] += 1

        # Count by tags
        tag_counts = {}
        for tag in ['model', 'nic', 'kernel', 'cpu', 'topo', 'perf']:
            values = defaultdict(int)
            for r in self.results:
                val = getattr(r, tag, None)
                if val:
                    values[val] += 1
            tag_counts[tag] = dict(values)

        # Get metric ranges
        metric_ranges = {}
        for metric in ['mean', 'min', 'max', 'busy_cpu']:
            values = [getattr(r, metric) for r in self.results if getattr(r, metric, None) is not None]
            if values:
                metric_ranges[metric] = {
                    'min': min(values),
                    'max': max(values),
                    'avg': statistics.mean(values)
                }

        return {
            'total_results': len(self.results),
            'benchmarks': dict(benchmark_counts),
            'tags': tag_counts,
            'metric_ranges': metric_ranges
        }

    def filter_results(
        self,
        benchmark: Optional[str] = None,
        model: Optional[str] = None,
        nic: Optional[str] = None,
        kernel: Optional[str] = None,
        topo: Optional[str] = None,
        **kwargs
    ) -> List[BenchmarkResult]:
        """
        Filter results by multiple criteria.

        Args:
            benchmark: Filter by benchmark type
            model: Filter by datapath model (OVNK, DPU, etc.)
            nic: Filter by NIC vendor (e810, e910, etc.)
            kernel: Filter by kernel version
            topo: Filter by topology
            **kwargs: Additional filter criteria

        Returns:
            Filtered list of results
        """
        filtered = self.results

        if benchmark:
            filtered = [r for r in filtered if r.benchmark == benchmark]
        if model:
            filtered = [r for r in filtered if r.model == model]
        if nic:
            filtered = [r for r in filtered if r.nic == nic]
        if kernel:
            filtered = [r for r in filtered if r.kernel == kernel]
        if topo:
            filtered = [r for r in filtered if r.topo == topo]

        # Apply additional filters
        for key, value in kwargs.items():
            if value is not None:
                filtered = [r for r in filtered if getattr(r, key, None) == value]

        return filtered
