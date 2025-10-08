"""
Data transformation implementations.

Handles transforming raw extracted data into final format.
Updated to support multiple iterations per file.
"""

import datetime
from typing import Dict, Any, Callable, Optional, List

from ..interfaces.protocols import DataTransformerInterface
from ..models.data_models import (
    ExtractedData, ProcessedResult, ResultStatus,
    MultiResultExtractedData
)


class StandardDataTransformer:
    """Standard data transformation implementation with iteration support."""
    
    def __init__(self):
        self.processors = {
            'trafficgen_result': self._process_trafficgen_result,
            'timestamp_converter': self._process_timestamp,
            'numeric_converter': self._process_numeric,
            'duration_parser': self._process_duration
        }
    
    def transform_data(self, extracted_data) -> ProcessedResult:
        """Transform extracted data into final format."""
        # Check if this is MultiResultExtractedData (new format) or ExtractedData (old format)
        if isinstance(extracted_data, MultiResultExtractedData):
            return self._transform_multi_result(extracted_data)
        else:
            return self._transform_legacy(extracted_data)
    
    def _transform_multi_result(self, extracted_data: MultiResultExtractedData) -> ProcessedResult:
        """Transform multi-iteration extracted data."""
        transformed_data = {
            "file_path": str(extracted_data.file_info.path),
            "benchmark": extracted_data.benchmark,
            "run_id": extracted_data.run_id,
            "common_params": extracted_data.common_params,
<<<<<<< HEAD
            "key_tags": extracted_data.extraction_metadata.get('key_tags', {}),
=======
>>>>>>> c6aaf49 (uperf,iperf,mbench working)
            "file_size": extracted_data.file_info.size,
            "file_modified": extracted_data.file_info.modified_time,
            "total_iterations": len(extracted_data.iterations),
            "iterations": []
        }
        
        # Transform each iteration
        for iteration in extracted_data.iterations:
            iteration_data = {
                'iteration_id': iteration.iteration_id,
                'unique_params': iteration.unique_params,
                'sample_count': len(iteration.samples),
                'result_count': len(iteration.results),  # NEW
                'samples': iteration.samples,
                'results': iteration.results,  # Now plural - list of results
                'test_description': self._generate_test_description(
                    iteration, 
                    extracted_data.benchmark
                )
            }
            transformed_data['iterations'].append(iteration_data)
        
        # Add summary statistics
        transformed_data['summary'] = self._generate_summary_statistics(extracted_data)
        
        # Determine processing status
        status = ResultStatus.SUCCESS if extracted_data.iterations else ResultStatus.FAILED
        
        processing_metadata = {
            'transformation_time': datetime.datetime.now().isoformat(),
            'status': status.value,
            'iterations_processed': len(extracted_data.iterations),
            'extraction_metadata': extracted_data.extraction_metadata
        }
        
        return ProcessedResult(
            file_path=str(extracted_data.file_info.path),
            benchmark=extracted_data.benchmark,
            data=transformed_data,
            processing_metadata=processing_metadata
        )
    
    def _transform_legacy(self, extracted_data: ExtractedData) -> ProcessedResult:
        """Transform legacy ExtractedData format."""
        transformed_data = {
            "file_path": str(extracted_data.file_info.path),
            "benchmark": extracted_data.benchmark,
            "file_size": extracted_data.file_info.size,
            "file_modified": extracted_data.file_info.modified_time
        }
        
        # Process each extracted field
        processing_errors = []
        for field_name, match_data in extracted_data.raw_matches.items():
            try:
                if match_data.get('processor') and match_data['processor'] in self.processors:
                    transformed_data[field_name] = self.processors[match_data['processor']](match_data)
                else:
                    # Default processing: use first group or full match
                    groups = match_data.get('groups', [])
                    transformed_data[field_name] = groups[0] if groups else match_data.get('full_match', '')
            except Exception as e:
                processing_errors.append(f"Error processing {field_name}: {e}")
                transformed_data[field_name] = f"ERROR: {e}"
        
        # Add metadata
        for field_name, groups in extracted_data.extraction_metadata.items():
            if field_name not in ['rules_applied', 'successful_matches', 'metadata_matches']:
                if isinstance(groups, tuple) and groups:
                    transformed_data[field_name] = groups[0]
                elif not isinstance(groups, (int, float, str, bool)):
                    continue  # Skip non-serializable metadata
                else:
                    transformed_data[field_name] = groups
        
        # Determine processing status
        status = self._determine_status_legacy(extracted_data, processing_errors)
        
        processing_metadata = {
            'transformation_time': datetime.datetime.now().isoformat(),
            'processors_used': [match_data.get('processor') for match_data in extracted_data.raw_matches.values() if match_data.get('processor')],
            'status': status.value,
            'processing_errors': processing_errors,
            'extraction_metadata': extracted_data.extraction_metadata
        }
        
        return ProcessedResult(
            file_path=str(extracted_data.file_info.path),
            benchmark=extracted_data.benchmark,
            data=transformed_data,
            processing_metadata=processing_metadata
        )
    
    def _generate_test_description(self, iteration, benchmark: str) -> str:
        """Generate human-readable test description."""
        params = iteration.unique_params
        results = iteration.results
        
        desc_parts = []
        
        # Add thread count if present
        if 'nthreads' in params:
            threads = params['nthreads']
            desc_parts.append(f"{threads} thread{'s' if threads != '1' else ''}")
        
        # Add test type
        if 'test-type' in params:
            desc_parts.append(f"{params['test-type']} test")
        
        # Add size parameters
        if 'wsize' in params:
            desc_parts.append(f"write={params['wsize']}B")
        if 'rsize' in params:
            desc_parts.append(f"read={params['rsize']}B")
        
        # Add result summary - show primary result
        if results:
            primary_result = self._get_primary_result(results)
            if primary_result and 'mean' in primary_result:
                mean_val = primary_result['mean']
                unit = primary_result.get('unit', primary_result.get('type', ''))
                desc_parts.append(f"→ {mean_val:.2f} {unit}")
        
        return ", ".join(desc_parts) if desc_parts else f"{benchmark} test"
   
    def _get_primary_result(self, results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Get the primary/most important result from a list."""
        if not results:
            return {}
        
        # Priority: Gbps > Mbps > transactions > connections
        priority_types = ['Gbps', 'Mbps', 'transactions-sec', 'connections-sec']
        
        for priority in priority_types:
            for result in results:
                if priority.lower() in result.get('type', '').lower():
                    return result
        
        # Return first result with mean
        for result in results:
            if 'mean' in result:
                return result
        
        return results[0]
 
    def _generate_summary_statistics(self, extracted_data: MultiResultExtractedData) -> Dict[str, Any]:
        """Generate summary statistics across all iterations."""
        iterations = extracted_data.iterations
        
        if not iterations:
            return {}
        
        # Collect all result means
        result_means = []
        result_types = set()
        
        for iteration in iterations:
            for result in iteration.results:
              if isinstance(result, dict):
                if 'mean' in result:
                    result_means.append(result['mean'])
                if 'type' in result:
                    result_types.add(result['type'])
        
        summary = {
            'total_iterations': len(iterations),
            'total_samples': sum(len(it.samples) for it in iterations),
            'result_types': list(result_types)
        }
        
        if result_means:
            summary.update({
                'overall_mean': sum(result_means) / len(result_means),
                'overall_min': min(result_means),
                'overall_max': max(result_means),
                'result_range': max(result_means) - min(result_means),
                'performance_summary': self._performance_summary(result_means)
            })
        
        return summary
    
    def _performance_summary(self, means) -> str:
        """Generate human-readable performance summary."""
        if not means:
            return "No performance data"
        
        min_val = min(means)
        max_val = max(means)
        avg_val = sum(means) / len(means)
        
        if len(means) == 1:
            return f"Single test: {avg_val:.2f}"
        
        variance_pct = ((max_val - min_val) / avg_val * 100) if avg_val > 0 else 0
        
        return f"Range: {min_val:.2f} - {max_val:.2f}, Avg: {avg_val:.2f}, Variance: {variance_pct:.1f}%"
    
    def _determine_status_legacy(self, extracted_data: ExtractedData, processing_errors: list) -> ResultStatus:
        """Determine the processing status based on extraction results."""
        total_rules = len(extracted_data.raw_matches)
        successful_matches = len([m for m in extracted_data.raw_matches.values() if m.get('groups')])
        
        if processing_errors:
            return ResultStatus.PARTIAL if successful_matches > 0 else ResultStatus.FAILED
        
        if successful_matches == 0:
            return ResultStatus.FAILED
        elif successful_matches < total_rules * 0.8:  # Less than 80% success
            return ResultStatus.PARTIAL
        else:
            return ResultStatus.SUCCESS
    
    def _process_trafficgen_result(self, match_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process trafficgen-specific result format."""
        groups = match_data.get('groups', [])
        if len(groups) >= 5:
            try:
                return {
                    "type": groups[0],
                    "samples": float(groups[1]),
                    "mean": float(groups[2]),
                    "min": float(groups[3]),
                    "max": float(groups[4]),
                    "stddev": float(groups[5]) if len(groups) > 5 else None
                }
            except (ValueError, IndexError) as e:
                return {"raw": groups, "error": str(e)}
        return {"raw": groups}
    
    def _process_timestamp(self, match_data: Dict[str, Any]) -> Optional[str]:
        """Process timestamp values."""
        groups = match_data.get('groups', [])
        if not groups:
            return None
        
        timestamp_str = groups[0]
        try:
            # Try different timestamp formats
            if timestamp_str.isdigit():
                # Unix timestamp
                timestamp = int(timestamp_str)
                if timestamp > 1e10:  # Milliseconds
                    timestamp = timestamp / 1000
                return datetime.datetime.fromtimestamp(timestamp).isoformat()
            else:
                # Try to parse as datetime string
                return timestamp_str  # Return as-is if can't parse
        except (ValueError, OSError):
            return timestamp_str
    
    def _process_numeric(self, match_data: Dict[str, Any]) -> Optional[float]:
        """Process numeric values."""
        groups = match_data.get('groups', [])
        if not groups:
            return None
        
        try:
            return float(groups[0])
        except ValueError:
            return groups[0]  # Return as string if not numeric
    
    def _process_duration(self, match_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process duration values."""
        groups = match_data.get('groups', [])
        if not groups:
            return {}
        
        duration_str = groups[0]
        try:
            # Extract number and unit
            import re
            match = re.match(r'([0-9.]+)\s*([a-zA-Z]+)', duration_str)
            if match:
                value, unit = match.groups()
                return {
                    "value": float(value),
                    "unit": unit.lower(),
                    "raw": duration_str
                }
        except (ValueError, AttributeError):
            pass
        
        return {"raw": duration_str}
    
    def add_processor(self, processor_name: str, processor_func: Callable):
        """Add a custom data processor."""
        self.processors[processor_name] = processor_func
    
    def remove_processor(self, processor_name: str) -> bool:
        """Remove a data processor."""
        if processor_name in self.processors:
            del self.processors[processor_name]
            return True
        return False


class ValidationAwareTransformer(StandardDataTransformer):
    """Data transformer that respects validation results."""
    
    def transform_data(self, extracted_data) -> ProcessedResult:
        """Transform data with validation awareness."""
        result = super().transform_data(extracted_data)
        
        # Add validation information to the result
        if hasattr(extracted_data, 'extraction_metadata'):
            validation_results = extracted_data.extraction_metadata.get('validation_results', {})
            if validation_results:
                result.processing_metadata['validation_summary'] = self._summarize_validation(validation_results)
                result.data['field_validation'] = validation_results
        
        return result
    
    def _summarize_validation(self, validation_results: Dict[str, Any]) -> Dict[str, Any]:
        """Create a summary of validation results."""
        total_fields = len(validation_results)
        valid_fields = sum(1 for v in validation_results.values() if v.get('is_valid', True))
        warning_count = sum(len(v.get('warnings', [])) for v in validation_results.values())
        error_count = sum(len(v.get('errors', [])) for v in validation_results.values())
        
        return {
            'total_fields': total_fields,
            'valid_fields': valid_fields,
            'validation_score': valid_fields / total_fields if total_fields > 0 else 0,
            'warning_count': warning_count,
            'error_count': error_count
        }


class BenchmarkSpecificTransformer(StandardDataTransformer):
    """Transformer with benchmark-specific processing logic."""
    
    def __init__(self):
        super().__init__()
        self.benchmark_transformers = {
            'trafficgen': self._transform_trafficgen_data,
            'iperf': self._transform_iperf_data,
            'fio': self._transform_fio_data
        }
    
    def _transform_trafficgen_data(self, data: Dict[str, Any], extracted_data) -> Dict[str, Any]:
        """Apply trafficgen-specific transformations."""
        enhancements = {}
        
        # Calculate throughput metrics
        if 'result' in data and isinstance(data['result'], dict):
            result_data = data['result']
            if 'mean' in result_data and 'type' in result_data:
                result_type = result_data['type']
                mean_value = result_data['mean']
                
                if 'pps' in result_type.lower():
                    # Convert PPS to approximate bandwidth (assuming average packet size)
                    avg_packet_size = 64  # bytes, configurable
                    enhancements['estimated_bandwidth_mbps'] = (mean_value * avg_packet_size * 8) / 1e6
        
        return enhancements
    
    def _transform_iperf_data(self, data: Dict[str, Any], extracted_data) -> Dict[str, Any]:
        """Apply iperf-specific transformations."""
        return {'benchmark_type': 'network_performance'}
    
    def _transform_fio_data(self, data: Dict[str, Any], extracted_data) -> Dict[str, Any]:
        """Apply fio-specific transformations."""
        return {'benchmark_type': 'storage_performance'}
    
    def add_benchmark_transformer(self, benchmark_name: str, transformer_func: Callable):
        """Add a custom benchmark transformer."""
        self.benchmark_transformers[benchmark_name] = transformer_func

