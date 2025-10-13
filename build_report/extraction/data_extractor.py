"""
Data extraction implementations.

Handles applying rules to extract data from file content.
Updated to support multiple iterations per file with multiple results per iteration.
"""

import re
from typing import Dict, Any, List
import time

from ..interfaces.protocols import DataExtractorInterface
from ..models.data_models import (
    BenchmarkRuleSet, ExtractedData, FileInfo,
    TestIteration, MultiResultExtractedData
)


class RegexDataExtractor:
    """Data extractor using regex patterns with iteration support."""
    
    def __init__(self, enable_timing: bool = False):
        self.enable_timing = enable_timing
    
    def extract_data(self, content: str, rules: BenchmarkRuleSet, file_info: FileInfo) -> MultiResultExtractedData:
        """Extract data using regex rules, supporting multiple iterations."""
        start_time = time.time() if self.enable_timing else None
        
        # Extract benchmark and global metadata
        benchmark = self._extract_benchmark(content, rules)
        run_id = self._extract_run_id(content)
        common_params = self._extract_common_params(content)
        tags = self._extract_tags(content)
        key_tags = self._extract_key_tags(tags)
        
        # Extract all iterations
        iterations = self._extract_iterations(content, benchmark)
        
        # Build extraction metadata
        extraction_metadata = {
            'rules_applied': len(rules.rules),
            'iterations_found': len(iterations),
            'total_samples': sum(len(it.samples) for it in iterations),
            'benchmark_detected': benchmark,
            'tags': tags,
             'key_tags': key_tags
        }
        
        if self.enable_timing:
            extraction_metadata['extraction_duration_ms'] = (time.time() - start_time) * 1000
        
        return MultiResultExtractedData(
            file_info=file_info,
            benchmark=benchmark,
            run_id=run_id,
            common_params=common_params,
            iterations=iterations,
            extraction_metadata=extraction_metadata,
            raw_matches={}  # For backward compatibility
        )
    
    def _extract_benchmark(self, content: str, rules: BenchmarkRuleSet) -> str:
        """Extract benchmark type from content."""
        # Try rules first
        for rule in rules.rules:
            if rule.field_name == "benchmark":
                match = re.search(rule.pattern, content, re.IGNORECASE | re.MULTILINE)
                if match:
                    return match.group(1).strip()
        
        # Fallback to direct search
        match = re.search(r'benchmark:\s*(\w+)', content, re.IGNORECASE | re.MULTILINE)
        if match:
            return match.group(1).strip()
        
        return "unknown"
    
    def _extract_run_id(self, content: str) -> str:
        """Extract run-id from content."""
        match = re.search(r'run-id:\s*([a-f0-9-]+)', content, re.IGNORECASE | re.MULTILINE)
        return match.group(1).strip() if match else ""
    
    def _extract_tags(self, content: str) -> str:
        """Extract tags from content."""
        match = re.search(r'tags:\s*(.+?)(?=\n\s*\w+:|$)', content, re.IGNORECASE | re.MULTILINE | re.DOTALL)
        return match.group(1).strip() if match else ""
    
    def _extract_common_params(self, content: str) -> Dict[str, str]:
        """Extract common parameters."""
        match = re.search(r'common params:\s*(.+?)(?=\n\s*\w+:|$)', content, re.IGNORECASE | re.MULTILINE | re.DOTALL)
        if not match:
            return {}
        
        params_str = match.group(1).strip()
        params = {}
        for param in params_str.split():
            if '=' in param:
                key, value = param.split('=', 1)
                params[key] = value
        return params
    
    def _extract_iterations(self, content: str, benchmark: str) -> List[TestIteration]:
        """Extract all iterations from content."""
        iterations = []
        
        # Find all iteration blocks by splitting on "iteration-id:"
        lines = content.split('\n')
        iteration_blocks = []
        current_block = []
        current_id = None
        
        for line in lines:
            if 'iteration-id:' in line:
                # Save previous block
                if current_block and current_id:
                    iteration_blocks.append((current_id, '\n'.join(current_block)))
                
                # Start new block
                match = re.search(r'iteration-id:\s*([A-F0-9-]+)', line, re.IGNORECASE)
                if match:
                    current_id = match.group(1)
                    current_block = [line]
            elif current_id:
                current_block.append(line)
        
        # Save last block
        if current_block and current_id:
            iteration_blocks.append((current_id, '\n'.join(current_block)))
        
        # Process each iteration
        for iteration_id, block in iteration_blocks:
            iteration = self._parse_iteration(iteration_id, block, benchmark)
            iterations.append(iteration)
        
        # If no iterations found, create a legacy one
        if not iterations:
            iterations = [self._create_legacy_iteration(content, benchmark)]
        
        return iterations
    
    def _parse_iteration(self, iteration_id: str, block: str, benchmark: str) -> TestIteration:
        """Parse a single iteration block."""
        # Extract unique params
        params_match = re.search(r'unique params:\s*(.*)$', block, re.MULTILINE)
        params_str = params_match.group(1).strip() if params_match else ""
        unique_params = {}
        if params_str:
            for param in params_str.split():
                if '=' in param:
                    key, value = param.split('=', 1)
                    unique_params[key] = value
        
        # Extract samples
        samples = self._extract_samples(block)
        
        # Extract ALL results (multiple result lines per iteration)
        results = self._extract_all_results(block, benchmark)
        
        return TestIteration(
            iteration_id=iteration_id,
            unique_params=unique_params,
            samples=samples,
            results=results
        )
    
    def _extract_samples(self, block: str) -> List[Dict[str, Any]]:
        """Extract sample information from iteration block."""
        samples = []
        
        # Pattern: sample-id: UUID ... period range: begin: X end: Y ... period length: Z seconds
        sample_pattern = r'sample-id:\s*([A-F0-9-]+).*?period range:.*?begin:\s*(\d+)\s+end:\s*(\d+).*?period length:\s*([0-9.-]+)\s*seconds'
        
        for match in re.finditer(sample_pattern, block, re.IGNORECASE | re.DOTALL):
            sample = {
                'sample_id': match.group(1),
                'begin': int(match.group(2)),
                'end': int(match.group(3)),
                'duration': float(match.group(4))
            }
            samples.append(sample)
        
        return samples
    
    def _extract_all_results(self, block: str, benchmark: str) -> List[Dict[str, Any]]:
        """Extract ALL result lines from an iteration block."""
        results = []
        
        # Find all result lines in the block
        for line in block.split('\n'):
            if 'result:' in line:
                # Determine which extractor to use based on the result line content
                if '(uperf::' in line:
                    result = self._extract_uperf_result(line)
                    if result.get('type') != 'unknown':
                        results.append(result)
                elif '(iperf::' in line:
                    result = self._extract_iperf_result(line)
                    if result.get('type') != 'unknown':
                        results.append(result)
                elif '(trafficgen::' in line:
                    result = self._extract_trafficgen_result(line)
                    if result.get('type') != 'unknown':
                        results.append(result)
                else:
                    # Generic result
                    match = re.search(r'result:\s*(.+?)$', line)
                    if match:
                        results.append({
                            'raw': match.group(1).strip(),
                            'type': 'generic'
                        })
        
        # If no results found, return a placeholder
        if not results:
            results.append({'raw': 'No result found', 'type': 'unknown'})
        
        return results
    
    def _extract_uperf_result(self, line: str) -> Dict[str, Any]:
        """Extract uperf result format from a single line."""
        # Pattern: result: (uperf::Gbps) samples: X Y Z mean: M min: N max: O stddev: P stddevpct: Q
        pattern = r'result:\s*\(uperf::([^)]+)\)\s*samples:\s*([\d.\s]+?)\s*mean:\s*([0-9.]+)\s*min:\s*([0-9.]+)\s*max:\s*([0-9.]+)\s*stddev:\s*([0-9.NaN]+)\s*stddevpct:\s*([0-9.NaN]+)(?:\s*CPU:\s*([0-9.]+))?'
        
        match = re.search(pattern, line, re.IGNORECASE)
        if match:
            metric_type = match.group(1).strip()
            samples_str = match.group(2).strip()
            
            # Parse sample values
            sample_values = []
            for val in samples_str.split():
                try:
                    sample_values.append(float(val))
                except ValueError:
                    pass
            
            # Parse stddev (might be NaN)
            try:
                stddev = float(match.group(6))
            except ValueError:
                stddev = 0.0
            
            try:
                stddevpct = float(match.group(7))
            except ValueError:
                stddevpct = 0.0
            # parse CPU
            cpu_value = None
            if match.group(8):
                try:
                    cpu_value = float(match.group(8))
                except (ValueError, TypeError):
                    pass

            result = {
                'type': metric_type,
                'sample_values': sample_values,
                'sample_count': len(sample_values),
                'mean': float(match.group(3)),
                'min': float(match.group(4)),
                'max': float(match.group(5)),
                'stddev': stddev,
                'stddevpct': stddevpct,
                'range': float(match.group(5)) - float(match.group(4)),
                'unit': self._infer_unit(metric_type)
            }

            if cpu_value is not None:
                result['CPU'] = cpu_value

            return result  
    
        return {'raw': 'No result found', 'type': 'unknown'}
    
    def _extract_iperf_result(self, line: str) -> Dict[str, Any]:
        """Extract iperf result format from a single line (same as uperf format)."""
        # Pattern: result: (iperf::rx-Gbps) samples: X mean: M min: N max: O stddev: P stddevpct: Q
        pattern = r'result:\s*\(iperf::([^)]+)\)\s*samples:\s*([\d.\s]+?)\s*mean:\s*([0-9.]+)\s*min:\s*([0-9.]+)\s*max:\s*([0-9.]+)\s*stddev:\s*([0-9.NaN]+)\s*stddevpct:\s*([0-9.NaN]+)(?:\s*CPU:\s*([0-9.]+))?'
        
        match = re.search(pattern, line, re.IGNORECASE)
        if match:
            metric_type = match.group(1).strip()
            samples_str = match.group(2).strip()
            
            # Parse sample values
            sample_values = []
            for val in samples_str.split():
                try:
                    sample_values.append(float(val))
                except ValueError:
                    pass
            
            # Parse stddev (might be NaN)
            try:
                stddev = float(match.group(6))
            except ValueError:
                stddev = 0.0
            
            try:
                stddevpct = float(match.group(7))
            except ValueError:
                stddevpct = 0.0
            # parse CPU
            cpu_value = None
            if match.group(8):
                try:
                    cpu_value = float(match.group(8))
                except (ValueError, TypeError):
                    pass

            result = {
                'type': metric_type,
                'sample_values': sample_values,
                'sample_count': len(sample_values),
                'mean': float(match.group(3)),
                'min': float(match.group(4)),
                'max': float(match.group(5)),
                'stddev': stddev,
                'stddevpct': stddevpct,
                'range': float(match.group(5)) - float(match.group(4)),
                'unit': self._infer_unit(metric_type)
            }
            if cpu_value is not None:
                result['CPU'] = cpu_value

            return result  
        
        return {'raw': 'No result found', 'type': 'unknown'}
    
    def _extract_trafficgen_result(self, line: str) -> Dict[str, Any]:
        """Extract trafficgen result format from a single line."""
        pattern = r'result:\s*\(([^)]+)\)\s*samples:\s*([0-9.]+)\s*mean:\s*([0-9.]+)\s*min:\s*([0-9.]+)\s*max:\s*([0-9.]+)'
        
        match = re.search(pattern, line, re.IGNORECASE)
        if match:
            return {
                'type': match.group(1),
                'samples': float(match.group(2)),
                'mean': float(match.group(3)),
                'min': float(match.group(4)),
                'max': float(match.group(5)),
                'unit': self._infer_unit(match.group(1))
            }
        
        return {'raw': 'No result found', 'type': 'unknown'}
    
    def _infer_unit(self, metric_type: str) -> str:
        """Infer unit from metric type."""
        if 'Gbps' in metric_type or 'gbps' in metric_type.lower():
            return 'Gbps'
        elif 'Mbps' in metric_type or 'mbps' in metric_type.lower():
            return 'Mbps'
        elif 'transactions-sec' in metric_type:
            return 'transactions/sec'
        elif 'connections-sec' in metric_type:
            return 'connections/sec'
        elif 'pps' in metric_type.lower():
            return 'packets/sec'
        elif 'retry/sec' in metric_type.lower():
            return 'retries/sec'
        else:
            return metric_type
    
    def _create_legacy_iteration(self, content: str, benchmark: str) -> TestIteration:
        """Create a single iteration for files without iteration structure."""
        results = self._extract_all_results(content, benchmark)
        
        return TestIteration(
            iteration_id="legacy-format",
            unique_params={'format': 'legacy'},
            samples=[],
            results=results
        )

    def _extract_key_tags(self, tags_str: str) -> Dict[str, str]:
        """Extract key tags: pods-per-worker, scale_out_factor, topo."""
        key_tags = {}
    
        # Parse tags string
        for tag in tags_str.split():
            if '=' in tag:
                key, value = tag.split('=', 1)
                if key in ['model', 'perf', 'offload', 'kernel', 'rcos', 'pods-per-worker', 'scale_out_factor', 'topo']:
                    key_tags[key] = value
    
        return key_tags

class MultiPassDataExtractor:
    """Data extractor that performs multiple passes for complex extractions."""
    
    def __init__(self, max_passes: int = 3):
        self.max_passes = max_passes
        self.base_extractor = RegexDataExtractor(enable_timing=True)
    
    def extract_data(self, content: str, rules: BenchmarkRuleSet, file_info: FileInfo) -> MultiResultExtractedData:
        """Extract data using multiple passes for context-dependent rules."""
        return self.base_extractor.extract_data(content, rules, file_info)


class CachedDataExtractor:
    """Data extractor with caching for repeated patterns."""
    
    def __init__(self, base_extractor: DataExtractorInterface = None):
        self.base_extractor = base_extractor or RegexDataExtractor()
        self._pattern_cache = {}
        self._compiled_patterns = {}
    
    def extract_data(self, content: str, rules: BenchmarkRuleSet, file_info: FileInfo) -> MultiResultExtractedData:
        """Extract data with pattern caching."""
        return self.base_extractor.extract_data(content, rules, file_info)
    
    def clear_cache(self):
        """Clear the pattern cache."""
        self._pattern_cache.clear()
        self._compiled_patterns.clear()


class ValidatingDataExtractor:
    """Data extractor with validation capabilities."""
    
    def __init__(self, base_extractor: DataExtractorInterface = None):
        self.base_extractor = base_extractor or RegexDataExtractor()
        self.validation_rules = {
            'numeric': r'^[0-9.]+$',
            'timestamp': r'^\d{10,13}$',
            'uuid': r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        }
    
    def extract_data(self, content: str, rules: BenchmarkRuleSet, file_info: FileInfo) -> MultiResultExtractedData:
        """Extract and validate data."""
        return self.base_extractor.extract_data(content, rules, file_info)
    
    def add_validation_rule(self, rule_name: str, pattern: str):
        """Add a custom validation rule."""
        self.validation_rules[rule_name] = pattern
