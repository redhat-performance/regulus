"""
Output generation implementations. V24

Handles creating various output formats for the processed results.
Now with full support for multiple iterations and multiple results per iteration.
"""

import json
import csv
import xml.etree.ElementTree as ET
from typing import Dict, List, Any, Optional
from pathlib import Path
import datetime

from ..interfaces.protocols import OutputGeneratorInterface
from ..models.data_models import ProcessedResult, SchemaInfo
from ..schema.schema_manager import SchemaManager


class JsonOutputGenerator:
    """JSON output generator."""
    
    def __init__(self, indent: int = 2, ensure_ascii: bool = False):
        self.indent = indent
        self.ensure_ascii = ensure_ascii
    
    def generate_output(self, results: List[ProcessedResult], output_path: str) -> None:
        """Generate JSON output file."""
        summary = self._build_summary_structure(results)
        
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(summary, f, indent=self.indent, ensure_ascii=self.ensure_ascii)
            print(f"JSON output generated: {output_path}")
        except Exception as e:
            print(f"Error generating JSON output: {e}")
    
    def _build_summary_structure(self, results: List[ProcessedResult]) -> Dict[str, Any]:
        """Build the summary data structure."""
        return {
            "generation_info": {
                "total_results": len(results),
                "timestamp": datetime.datetime.now().isoformat(),
                "benchmarks": list(set(r.benchmark for r in results))
            },
            "results": [r.data for r in results],
            "summary_by_benchmark": self._create_benchmark_summary(results),
            "processing_metadata": [r.processing_metadata for r in results]
        }
    
    def _create_benchmark_summary(self, results: List[ProcessedResult]) -> Dict[str, Any]:
        """Create summary grouped by benchmark."""
        summary = {}
        for result in results:
            benchmark = result.benchmark
            if benchmark not in summary:
                summary[benchmark] = {"count": 0, "files": []}
            summary[benchmark]["count"] += 1
            summary[benchmark]["files"].append(result.file_path)
        return summary


class SchemaAwareOutputGenerator(JsonOutputGenerator):
    """Output generator with schema awareness and validation."""
    
    def __init__(self, schema_manager: SchemaManager, **kwargs):
        super().__init__(**kwargs)
        self.schema_manager = schema_manager
        self.validate_output = True
    
    def generate_output(self, results: List[ProcessedResult], output_path: str) -> None:
        """Generate schema-compliant output with validation."""
        summary = self._build_schema_compliant_summary(results)
        
        # Validate against schema
        if self.validate_output:
            is_valid, error_msg = self.schema_manager.validate_report(summary)
            if not is_valid:
                print(f"Schema validation failed: {error_msg}")
                summary["validation_report"] = {
                    "schema_validation": False,
                    "validation_errors": [error_msg] if error_msg else [],
                    "validation_warnings": [],
                    "data_quality_score": 0.0
                }
            else:
                summary["validation_report"] = {
                    "schema_validation": True,
                    "validation_errors": [],
                    "validation_warnings": [],
                    "data_quality_score": 1.0
                }
        
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(summary, f, indent=self.indent, ensure_ascii=self.ensure_ascii)
            print(f"Schema-compliant output generated: {output_path}")
            
            # Also export the schema
            schema_path = output_path.replace('.json', '_schema.json')
            self.schema_manager.export_schema(schema_path)
            
        except Exception as e:
            print(f"Error generating output: {e}")
    
    def _build_schema_compliant_summary(self, results: List[ProcessedResult]) -> Dict[str, Any]:
        """Build summary structure compliant with current schema version."""
        schema_info = self.schema_manager.get_schema_info()
        successful_results = [r for r in results if r.processing_metadata.get('status') != 'failed']
        failed_results = [r for r in results if r.processing_metadata.get('status') == 'failed']
        
        summary = {
            "schema_info": schema_info.to_dict(),
            "generation_info": {
                "total_results": len(results),
                "successful_results": len(successful_results),
                "failed_results": len(failed_results),
                "timestamp": datetime.datetime.now().isoformat(),
                "benchmarks": list(set(r.benchmark for r in results)),
                "processing_duration_seconds": 0.0
            },
            "benchmark_definitions": self._generate_benchmark_definitions(results),
            "results": [self._enhance_result_data(r) for r in results],
            "summary_by_benchmark": self._create_enhanced_benchmark_summary(results)
        }
        
        return summary
    
    def _enhance_result_data(self, result: ProcessedResult) -> Dict[str, Any]:
        """Enhance result data with schema-compliant structure."""
        enhanced = result.data.copy()
        enhanced.update({
            "processing_status": result.processing_metadata.get('status', 'success'),
            "file_metadata": {
                "size_bytes": enhanced.get('file_size', 0),
                "modified_timestamp": enhanced.get('file_modified', 0)
            },
            "extraction_metadata": {
                "rules_applied": result.processing_metadata.get('extraction_metadata', {}).get('rules_applied', 0),
                "fields_extracted": len(enhanced) - 4
            }
        })
        return enhanced
    
    def _generate_benchmark_definitions(self, results: List[ProcessedResult]) -> Dict[str, Any]:
        """Generate benchmark definitions based on observed data."""
        definitions = {}
        
        benchmark_fields = {}
        for result in results:
            benchmark = result.benchmark
            if benchmark not in benchmark_fields:
                benchmark_fields[benchmark] = set()
            benchmark_fields[benchmark].update(result.data.keys())
        
        for benchmark, fields in benchmark_fields.items():
            definitions[benchmark] = {
                "description": f"Auto-generated definition for {benchmark} benchmark",
                "required_fields": ["file_path", "benchmark"],
                "optional_fields": list(fields - {"file_path", "benchmark"}),
                "result_format": "structured",
                "validation_rules": []
            }
        
        return definitions
    
    def _create_enhanced_benchmark_summary(self, results: List[ProcessedResult]) -> Dict[str, Any]:
        """Create enhanced benchmark summary with success metrics."""
        summary = {}
        
        for result in results:
            benchmark = result.benchmark
            if benchmark not in summary:
                summary[benchmark] = {
                    "count": 0,
                    "successful_count": 0,
                    "failed_count": 0,
                    "files": [],
                    "success_rate": 0.0
                }
            
            summary[benchmark]["count"] += 1
            summary[benchmark]["files"].append(result.file_path)
            
            status = result.processing_metadata.get('status', 'success')
            if status == 'success':
                summary[benchmark]["successful_count"] += 1
            else:
                summary[benchmark]["failed_count"] += 1
        
        # Calculate success rates
        for benchmark_data in summary.values():
            if benchmark_data["count"] > 0:
                benchmark_data["success_rate"] = benchmark_data["successful_count"] / benchmark_data["count"]
        
        return summary

class CsvOutputGenerator:
    """CSV output generator for tabular data export - iteration level."""
    
    def __init__(self, delimiter: str = ',', include_metadata: bool = False, base_url: str = ''):
        self.delimiter = delimiter
        self.include_metadata = include_metadata
        self.base_url = base_url

    def _get_param_value(self, param_name: str, unique_params: dict, common_params: dict):
        """Get parameter value: check unique_params first, then fall back to common_params."""
        return unique_params.get(param_name) or common_params.get(param_name)
    
    def generate_output(self, results: List[ProcessedResult], output_path: str) -> None:
        """Generate CSV output file with one row per iteration."""
        if not results:
            print("No results to export to CSV")
            return
        
        try:
            with open(output_path, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f, delimiter=self.delimiter)
                
                # Generate headers
                headers = self._generate_headers(results)
                writer.writerow(headers)
                
                # Write one row per iteration
                for result in results:
                    rows = self._result_to_rows(result, headers)
                    for row in rows:
                        writer.writerow(row)
            
            print(f"CSV output generated: {output_path}")
        except Exception as e:
            print(f"Error generating CSV output: {e}")
    
    def _generate_headers(self, results: List[ProcessedResult]) -> List[str]:
        """Generate CSV headers from iteration data."""
        # Standard columns in desired order
        standard_headers = [
            'file',           # First
            'benchmark',     #  skip 'status',
            'model',          # Move model/offload/cpu up
            'perf',
            'config',
            'cpu',
            'test_type',
            'threads',
            'wsize',
            'rsize',
            'samples',
            'mean',
            'unit',
            'busyCPU',
            'stddev%',
            'iteration_id',
            'protocol'        # Last
        ]

        # Collect all unique keys from iterations
        all_keys = set()
        for result in results:
            iterations = result.data.get('iterations', [])
            for iteration in iterations:
                unique_params = iteration.get('unique_params', {})
                all_keys.update(unique_params.keys())

                # Get result fields
                iteration_results = iteration.get('results', [])
                if iteration_results:
                    all_keys.update(iteration_results[0].keys())

        # Combine standard headers with any extra fields found
        final_headers = []
        for h in standard_headers:
            if h not in final_headers:
                final_headers.append(h)

        # Add any extra fields not in standard list
        for key in sorted(all_keys):
            if key not in final_headers and key not in ['type', 'sample_values', 'sample_count', 'range']:
                final_headers.append(key)

        return final_headers

    def _result_to_rows(self, result: ProcessedResult, headers: List[str]) -> List[List[str]]:
        """Convert a result with multiple iterations into multiple CSV rows."""
        rows = []

        file_name = Path(result.file_path).name
        benchmark = result.benchmark
        status = result.processing_metadata.get('status', 'unknown')

        # Get file-level common params and tags
        file_common_params = result.data.get('common_params', {})
        key_tags = result.data.get('key_tags', {})

        # Config string
        config = f"{key_tags.get('pods-per-worker', '?')},{key_tags.get('scale_out_factor', '?')},{key_tags.get('topo', '?')}"

        # Get iterations
        iterations = result.data.get('iterations', [])

        if not iterations:
            # No iterations - create one row with basic info
            row = [''] * len(headers)
            if 'file' in headers:
                if self.base_url:
                    full_url = f"{self.base_url}/{result.file_path}"
                    row[headers.index('file')] = f'=HYPERLINK("{full_url}","{file_name}")'
                else:
                    row[headers.index('file')] = file_name
            if 'benchmark' in headers:
                row[headers.index('benchmark')] = benchmark
            if 'status' in headers:
                row[headers.index('status')] = status
            if 'config' in headers:
                row[headers.index('config')] = config
            rows.append(row)
        else:
            # One row per iteration
            for iteration in iterations:
                row = self._iteration_to_row(
                    iteration, headers, file_name, benchmark, status, 
                    config, file_common_params, key_tags, result.file_path
                )
                rows.append(row)

        return rows

    def _iteration_to_row(self, iteration: Dict, headers: List[str], file_name: str, 
                      benchmark: str, status: str, config: str, 
                      file_common_params: Dict, key_tags: Dict,
                      file_path: str = '') -> List[str]:
        """Convert a single iteration to a CSV row."""
        row = [''] * len(headers)

        iteration_id = iteration.get('iteration_id', '')
        unique_params = iteration.get('unique_params', {})
        iteration_results = iteration.get('results', [])

        # Helper to get param value
        def get_param(key):
            return unique_params.get(key) or file_common_params.get(key) or ''

        # Fill in standard columns
        if 'file' in headers:
            if self.base_url:
                full_url = f"{self.base_url}/{file_path}"
                row[headers.index('file')] = f'=HYPERLINK("{full_url}","{file_name}")'
            else:
                row[headers.index('file')] = file_name
        if 'benchmark' in headers:
            row[headers.index('benchmark')] = benchmark
        if 'status' in headers:
            row[headers.index('status')] = status
        if 'config' in headers:
            row[headers.index('config')] = config
        if 'iteration_id' in headers:
            row[headers.index('iteration_id')] = iteration_id[:16]  # Shortened

        # Protocol and test type
        protocol = get_param('protocol')
        test_type = get_param('test-type')

        if 'protocol' in headers:
            row[headers.index('protocol')] = protocol

        if 'test_type' in headers:
            if test_type and protocol:
                row[headers.index('test_type')] = f"{protocol}, {test_type}"
            elif test_type:
                row[headers.index('test_type')] = test_type
            elif protocol:
                row[headers.index('test_type')] = protocol
        # Check for iperf3 custom/passthru parameters (same as HTML)
        if benchmark == 'iperf':
            known_params = {'protocol', 'max-loss-pct', 'bitrate-range', 'length', 'nthreads',
                        'test-type', 'wsize', 'rsize', 'num_clients', 'ifname', 'ipv', 'time'}
            has_custom = any(key not in known_params for key in unique_params.keys())
            if not has_custom:
                has_custom = any(key not in known_params for key in file_common_params.keys())
            if has_custom and 'test_type' in headers:
                current_test_type = row[headers.index('test_type')]
                if current_test_type:
                    row[headers.index('test_type')] = f"{current_test_type}, custom"
        # Other params
        if 'threads' in headers:
            threads = self._get_param_value('nthreads', unique_params, file_common_params)
            row[headers.index('threads')] = threads if threads else ''
        if 'wsize' in headers:
            # Try wsize first, then length (for iperf)
            wsize = self._get_param_value('wsize', unique_params, file_common_params)
            if not wsize:
                wsize = self._get_param_value('length', unique_params, file_common_params)
            row[headers.index('wsize')] = wsize if wsize else ''
        if 'rsize' in headers:
            rsize = self._get_param_value('rsize', unique_params, file_common_params)
            row[headers.index('rsize')] = rsize if rsize else ''

        # Tags
        if 'model' in headers:
            row[headers.index('model')] = key_tags.get('model', '')
        if 'perf' in headers:
            row[headers.index('perf')] = key_tags.get('perf', '')
        if 'cpu' in headers:
            row[headers.index('cpu')] = key_tags.get('cpu', '')

        # Results data
        if iteration_results and len(iteration_results) > 0:
            primary_result = iteration_results[0]

            if 'mean' in headers and 'mean' in primary_result:
                mean = primary_result['mean']
                row[headers.index('mean')] = f"{mean:.2f}" if isinstance(mean, (int, float)) else str(mean)

            if 'unit' in headers and 'unit' in primary_result:
                row[headers.index('unit')] = primary_result['unit']

            if 'samples' in headers and 'sample_count' in primary_result:
                row[headers.index('samples')] = str(primary_result['sample_count'])

            if 'stddev%' in headers and 'stddevpct' in primary_result:
                stddev = primary_result['stddevpct']
                if isinstance(stddev, (int, float)) and stddev > 0:
                    row[headers.index('stddev%')] = f"{stddev:.2f}"

            if 'busyCPU' in headers and 'busyCPU' in primary_result:
                cpu = primary_result['busyCPU']
                if isinstance(cpu, (int, float)):
                    row[headers.index('busyCPU')] = f"{cpu:.2f}"

        return row

class XmlOutputGenerator:
    """XML output generator."""
    
    def __init__(self, root_element: str = "build_report", pretty_print: bool = True):
        self.root_element = root_element
        self.pretty_print = pretty_print
    
    def generate_output(self, results: List[ProcessedResult], output_path: str) -> None:
        """Generate XML output file."""
        try:
            root = ET.Element(self.root_element)
            
            # Add metadata
            metadata_elem = ET.SubElement(root, "metadata")
            ET.SubElement(metadata_elem, "timestamp").text = datetime.datetime.now().isoformat()
            ET.SubElement(metadata_elem, "total_results").text = str(len(results))
            
            # Add results
            results_elem = ET.SubElement(root, "results")
            for result in results:
                self._add_result_to_xml(results_elem, result)
            
            # Write to file
            tree = ET.ElementTree(root)
            if self.pretty_print:
                self._indent(root)
            
            tree.write(output_path, encoding='utf-8', xml_declaration=True)
            print(f"XML output generated: {output_path}")
            
        except Exception as e:
            print(f"Error generating XML output: {e}")
    
    def _add_result_to_xml(self, parent: ET.Element, result: ProcessedResult) -> None:
        """Add a result to the XML structure."""
        result_elem = ET.SubElement(parent, "result")
        result_elem.set("benchmark", result.benchmark)
        result_elem.set("file_path", result.file_path)
        
        for key, value in result.data.items():
            if key in ["benchmark", "file_path"]:
                continue  # Already added as attributes
            
            elem = ET.SubElement(result_elem, key)
            if isinstance(value, dict):
                for sub_key, sub_value in value.items():
                    sub_elem = ET.SubElement(elem, sub_key)
                    sub_elem.text = str(sub_value)
            elif isinstance(value, list):
                for item in value:
                    item_elem = ET.SubElement(elem, "item")
                    item_elem.text = str(item)
            else:
                elem.text = str(value)
    
    def _indent(self, elem: ET.Element, level: int = 0) -> None:
        """Add indentation for pretty printing."""
        indent = "\n" + level * "  "
        if len(elem):
            if not elem.text or not elem.text.strip():
                elem.text = indent + "  "
            if not elem.tail or not elem.tail.strip():
                elem.tail = indent
            for elem in elem:
                self._indent(elem, level + 1)
            if not elem.tail or not elem.tail.strip():
                elem.tail = indent
        else:
            if level and (not elem.tail or not elem.tail.strip()):
                elem.tail = indent


class MultiFormatOutputGenerator:
    """Output generator that can produce multiple formats simultaneously."""
    
    def __init__(self, schema_manager: Optional[SchemaManager] = None):
        self.schema_manager = schema_manager
        self.generators = {
            'json': SchemaAwareOutputGenerator(schema_manager) if schema_manager else JsonOutputGenerator(),
            'csv': CsvOutputGenerator(),
            'xml': XmlOutputGenerator()
        }
        self.enabled_formats = ['json']  # Default to JSON only
    
    def enable_format(self, format_name: str) -> bool:
        """Enable a specific output format."""
        if format_name in self.generators:
            if format_name not in self.enabled_formats:
                self.enabled_formats.append(format_name)
            return True
        return False
    
    def disable_format(self, format_name: str) -> bool:
        """Disable a specific output format."""
        if format_name in self.enabled_formats:
            self.enabled_formats.remove(format_name)
            return True
        return False
    
    def generate_output(self, results: List[ProcessedResult], output_path: str) -> None:
        """Generate output in all enabled formats."""
        base_path = Path(output_path)
        base_name = base_path.stem
        base_dir = base_path.parent
        
        for format_name in self.enabled_formats:
            if format_name in self.generators:
                try:
                    if format_name == 'json':
                        format_path = base_dir / f"{base_name}.json"
                    elif format_name == 'csv':
                        format_path = base_dir / f"{base_name}.csv"
                    elif format_name == 'xml':
                        format_path = base_dir / f"{base_name}.xml"
                    else:
                        format_path = base_dir / f"{base_name}.{format_name}"
                    
                    self.generators[format_name].generate_output(results, str(format_path))
                except Exception as e:
                    print(f"Error generating {format_name} output: {e}")
    
    def add_custom_generator(self, format_name: str, generator: OutputGeneratorInterface):
        """Add a custom output generator."""
        self.generators[format_name] = generator
    
    def get_enabled_formats(self) -> List[str]:
        """Get list of currently enabled formats."""
        return self.enabled_formats.copy()


class HtmlOutputGenerator:
    """HTML output generator with rich formatting and full iteration support."""
    
    def __init__(self, template_style: str = "bootstrap", include_charts: bool = True):
        self.template_style = template_style
        self.include_charts = include_charts

    def _get_param_value(self, param_name: str, unique_params: dict, common_params: dict):
        """Get parameter value: check unique_params first, then fall back to common_params."""
        return unique_params.get(param_name) or common_params.get(param_name)    

    def generate_output(self, results: List[ProcessedResult], output_path: str) -> None:
        """Generate HTML output file."""
        try:
            html_content = self._build_html_report(results)
            
            # Ensure .html extension
            if not output_path.endswith('.html'):
                output_path = output_path.replace('.json', '.html').replace('.xml', '.html')
                if not output_path.endswith('.html'):
                    output_path += '.html'
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(html_content)
            
            print(f"HTML report generated: {output_path}")
        except Exception as e:
            print(f"Error generating HTML output: {e}")
    
    def _build_html_report(self, results: List[ProcessedResult]) -> str:
        """Build complete HTML report."""
        summary_stats = self._calculate_summary_stats(results)
        benchmark_data = self._group_by_benchmark(results)
        
        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dataplane Performance Report Summary</title>
    {self._get_css_styles()}
    {self._get_chart_scripts() if self.include_charts else ''}
</head>
<body>
    <div class="container">
        {self._generate_header(summary_stats)}
        {self._generate_summary_cards(summary_stats)}
        {self._generate_benchmark_sections(benchmark_data)}
        {self._generate_detailed_results_table(results)}
        {self._generate_charts_section(benchmark_data) if self.include_charts else ''}
        {self._generate_footer()}
    </div>
    {self._get_javascript() if self.include_charts else ''}
</body>
</html>"""
        return html
    
    def _calculate_summary_stats(self, results: List[ProcessedResult]) -> Dict[str, Any]:
        """Calculate summary statistics including iteration counts."""
        total_files = len(results)
        successful = len([r for r in results if r.processing_metadata.get('status') == 'success'])
        failed = total_files - successful
        benchmarks = list(set(r.benchmark for r in results))
        
        # Calculate total iterations across all files
        total_iterations = 0
        for result in results:
            iterations = result.data.get('iterations', [])
            total_iterations += len(iterations)
        
        # Calculate file size stats
        file_sizes = [r.data.get('file_size', 0) for r in results]
        avg_file_size = sum(file_sizes) / len(file_sizes) if file_sizes else 0

        # Extract kernel and rcos from tags (NEW)
        kernels = set()
        rcos_versions = set()
        for result in results:
            key_tags = result.data.get('key_tags', {})
            if 'kernel' in key_tags:
                kernels.add(key_tags['kernel'])
            if 'rcos' in key_tags:
                rcos_versions.add(key_tags['rcos'])
        return {
            'total_files': total_files,
            'total_iterations': total_iterations,
            'successful': successful,
            'failed': failed,
            'success_rate': (successful / total_files * 100) if total_files > 0 else 0,
            'benchmarks': benchmarks,
            'benchmark_count': len(benchmarks),
            'avg_file_size': avg_file_size,
            'kernel': ', '.join(sorted(kernels)) if kernels else 'Unknown',
            'rcos': ', '.join(sorted(rcos_versions)) if rcos_versions else 'Unknown',
            'timestamp': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    def _group_by_benchmark(self, results: List[ProcessedResult]) -> Dict[str, List[ProcessedResult]]:
        """Group results by benchmark type."""
        groups = {}
        for result in results:
            benchmark = result.benchmark
            if benchmark not in groups:
                groups[benchmark] = []
            groups[benchmark].append(result)
        return groups
    
    def _generate_header(self, stats: Dict[str, Any]) -> str:
        """Generate HTML header section with title and summary stats."""
        return f"""
        <header class="header">
            <h1><i class="icon">📊</i> Regulus/Crucible Performance Report Summary</h1>
            <p class="subtitle">Generated on {stats['timestamp']}</p>
            <p class="subtitle">Kernel: {stats['kernel']} | RCOS: {stats['rcos']}</p>

            <!-- Regex Filter Box -->
            <div style="margin: 20px 0; padding: 15px; background: #f8fafc; border-radius: 8px; border: 1px solid #e2e8f0;">
                <label for="filterInput" style="display: block; margin-bottom: 8px; font-weight: 500; color: #374151;">
                    Filter by Regex Pattern:
                </label>
                <input type="text" id="filterInput" placeholder="e.g., tcp|udp or .*200Mbps.* or ^test.*"
                       style="width: calc(100% - 150px); padding: 10px; font-size: 0.95rem; border: 2px solid #cbd5e1;
                              border-radius: 6px; font-family: 'Courier New', monospace;">
                <button onclick="clearFilter()"
                        style="margin-left: 10px; padding: 10px 20px; background: #64748b; color: white;
                               border: none; border-radius: 6px; cursor: pointer; font-weight: 500;">
                    Clear
                </button>
                <div id="matchCount" style="margin-top: 8px; color: #64748b; font-weight: 500;"></div>
            </div>
        </header>
        """
    
    def _generate_summary_cards(self, stats: Dict[str, Any]) -> str:
        """Generate summary cards section."""
        return f"""
        <section class="summary-cards">
            <div class="card success">
                <div class="card-header">
                    <h3>📁 Total Files</h3>
                </div>
                <div class="card-body">
                    <div class="metric">{stats['total_files']}</div>
                    <div class="detail">Files processed</div>
                </div>
            </div>
            
            <div class="card info">
                <div class="card-header">
                    <h3>🔄 Total Iterations</h3>
                </div>
                <div class="card-body">
                    <div class="metric">{stats['total_iterations']}</div>
                    <div class="detail">Test iterations found</div>
                </div>
            </div>
            
            <div class="card {'success' if stats['success_rate'] > 90 else 'warning' if stats['success_rate'] > 70 else 'danger'}">
                <div class="card-header">
                    <h3>✅ Success Rate</h3>
                </div>
                <div class="card-body">
                    <div class="metric">{stats['success_rate']:.1f}%</div>
                    <div class="detail">{stats['successful']}/{stats['total_files']} successful</div>
                </div>
            </div>
            
            <div class="card neutral">
                <div class="card-header">
                    <h3>🔧 Benchmarks</h3>
                </div>
                <div class="card-body">
                    <div class="metric">{stats['benchmark_count']}</div>
                    <div class="detail">Different types found</div>
                </div>
            </div>
        </section>
        """
    
    def _generate_benchmark_sections(self, benchmark_data: Dict[str, List[ProcessedResult]]) -> str:
        """Generate sections for each benchmark type."""
        sections = []
        
        for benchmark, results in benchmark_data.items():
            success_count = len([r for r in results if r.processing_metadata.get('status') == 'success'])
            
            # Count total iterations for this benchmark
            total_iterations = sum(len(r.data.get('iterations', [])) for r in results)
            
            # Extract key metrics for this benchmark
            key_metrics = self._extract_benchmark_metrics(benchmark, results)
            
            section = f"""
            <section class="benchmark-section">
                <h2>🚀 {benchmark.title()} Benchmark</h2>
                <div class="benchmark-stats">
                    <span class="stat">Files: {len(results)}</span>
                    <span class="stat">Iterations: {total_iterations}</span>
                    <span class="stat">Success: {success_count}/{len(results)}</span>
                    <span class="stat">Rate: {(success_count/len(results)*100):.1f}%</span>
                </div>
                
                {self._generate_metrics_table(key_metrics)}
                
                <details class="file-list">
                    <summary>📋 Files in this benchmark ({len(results)})</summary>
                    <ul class="file-list-items">
                        {self._generate_file_list(results)}
                    </ul>
                </details>
            </section>
            """
            sections.append(section)
        
        return '\n'.join(sections)
    
    def _extract_benchmark_metrics(self, benchmark: str, results: List[ProcessedResult]) -> List[Dict[str, Any]]:
        """Extract key metrics for a benchmark - ONE METRIC PER ITERATION."""
        metrics = []
        
        for result in results:
            data = result.data
            file_name = Path(result.file_path).name
            # Get common_params from file level
            file_common_params = data.get('common_params', {})
            file_path = result.file_path
            status = result.processing_metadata.get('status', 'unknown')
            
            # Get all iterations from this file
            iterations = data.get('iterations', [])
            
            if not iterations:
                # No iterations found - create single metric entry
                metrics.append({
                    'file': file_name,
                    'file_path': file_path,
                    'status': status,
                    'iteration': 'N/A',
                    'result': 'No iterations found'
                })
            else:
                # Create one metric entry per iteration
                for iteration in iterations:
                    iteration_id = iteration.get('iteration_id', 'unknown')
                    unique_params = iteration.get('unique_params', {})
                    iteration_results = iteration.get('results', [])  # Now plural - list of results
                    
                    metric = {
                        'file': file_name,
                        'file_path': file_path,
                        'status': status,
                        'iteration': iteration_id[:8] + '...',
                    }
                    
                    # Add key tags in compact format (NEW)
                    key_tags = data.get('key_tags', {})
                    tag_parts = [
                        key_tags.get('pods-per-worker', '?'),
                        key_tags.get('scale_out_factor', '?'),
                        key_tags.get('topo', '?')
                    ]
                    metric['config'] = ','.join(tag_parts)

                    if 'model' in key_tags:
                        metric['model'] = key_tags['model']
                    if 'offload' in key_tags:
                        metric['offload'] = key_tags['offload']
                    if 'perf' in key_tags:
                        metric['perf'] = key_tags['perf']
                    if 'cpu' in key_tags:
                        metric['cpu'] = key_tags['cpu']

                    # Add test configuration - use helper for ALL params
                    protocol = self._get_param_value('protocol', unique_params, file_common_params)
                    
                    # Handle iperf benchmark specially
                    if benchmark == 'iperf3' or benchmark == 'iperf':
                        # For iperf, check for max-loss-pct or bitrate-range as the "test type"
                        max_loss_pct = self._get_param_value('max-loss-pct', unique_params, file_common_params)
                        bitrate_range = self._get_param_value('bitrate-range', unique_params, file_common_params)
                        
                        if max_loss_pct is not None:
                            if protocol:
                                metric['test_type'] = f"{protocol}, max-loss-pct={max_loss_pct}"
                            else:
                                metric['test_type'] = f"max-loss-pct={max_loss_pct}"
                        elif bitrate_range:
                            # Don't show the actual list, just use it as test type indicator
                            if protocol:
                                metric['test_type'] = f"{protocol}, bitrate-range"
                            else:
                                metric['test_type'] = "bitrate-range"
                        elif protocol:
                            metric['test_type'] = protocol

                        length = self._get_param_value('length', unique_params, file_common_params)
                        if length:
                            metric['wsize'] = length
#
                        # Check for custom parameters and append ",special"
                        known_params = {'protocol', 'max-loss-pct', 'bitrate-range', 'length', 'nthreads', 
                                        'test-type', 'wsize', 'rsize', 'num_clients','ifname','ipv','time'}
    
                        has_custom = any(key not in known_params for key in unique_params.keys())
                        if not has_custom:
                            has_custom = any(key not in known_params for key in file_common_params.keys())
    
                        if has_custom and 'test_type' in metric:
                            metric['test_type'] += ', custom'
#
                    
                    nthreads = self._get_param_value('nthreads', unique_params, file_common_params)
                    if nthreads:
                        metric['threads'] = nthreads
                    
                    test_type = self._get_param_value('test-type', unique_params, file_common_params)
                    if test_type:
                        # Combine protocol with test-type if protocol exists (for uperf)
                        if protocol:
                            metric['test_type'] = f"{protocol}, {test_type}"
                        else:
                            metric['test_type'] = test_type
                    
                    wsize = self._get_param_value('wsize', unique_params, file_common_params)
                    if wsize:
                        metric['wsize'] = wsize
                    
                    rsize = self._get_param_value('rsize', unique_params, file_common_params)
                    if rsize:
                        metric['rsize'] = rsize

                    # Extract result metrics from first/primary result
                    if iteration_results and isinstance(iteration_results, list) and len(iteration_results) > 0:
                        primary_result = iteration_results[0]  # Take first result
                        if isinstance(primary_result, dict):
                            if 'mean' in primary_result:
                                mean = primary_result['mean']
                                if isinstance(mean, (int, float)):
                                    metric['mean'] = f"{mean:,.2f}"
                                else:
                                    metric['mean'] = str(mean)
                            
                            #if 'type' in primary_result:
                            #    metric['metric_type'] = primary_result['type']
                            
                            if 'unit' in primary_result:
                                metric['unit'] = primary_result['unit']
                            
                            if 'sample_count' in primary_result:
                                metric['samples'] = primary_result['sample_count']
                            
                            if 'stddevpct' in primary_result:
                                stddev = primary_result['stddevpct']
                                if isinstance(stddev, (int, float)) and stddev > 0:
                                    metric['stddev%'] = f"{stddev:.2f}%"

                            if 'busyCPU' in primary_result:
                                cpu = primary_result['busyCPU']
                                if isinstance(cpu, (int, float)):
                                    metric['busyCPU'] = f"{cpu:.2f}"
                                else:
                                    metric['busyCPU'] = str(cpu)
                    
                    metrics.append(metric)
        
        return metrics
    
    def _generate_metrics_table(self, metrics: List[Dict[str, Any]]) -> str:
        """Generate metrics table for a benchmark."""
        if not metrics:
            return "<p>No metrics available</p>"
        
        # Get all unique keys (columns)
        all_keys = set()
        for metric in metrics:
            all_keys.update(metric.keys())

        # Remove status and file from main columns (they'll be handled specially)
        #columns = sorted([k for k in all_keys if k not in ['file', 'file_path', 'status']])
        column_order = ['model','perf', 'offload', 'config', 'cpu', 'test_type', 'threads', 'wsize', 'rsize', 'samples', 'mean', 'unit', 'busyCPU', 'stddev%', 'iteration']

        # Sort with custom order
        def custom_sort(col):
            try:
                return column_order.index(col)
            except ValueError:
                return 999  # Put unknown columns at end

        columns = sorted([k for k in all_keys if k not in ['file', 'file_path', 'status']], 
                 key=custom_sort)

        table = """
        <div class="metrics-table-container">
            <table class="metrics-table">
                <thead>
                    <tr>
                        <th style="width: 40px;">#</th>
                        <th>📄 File</th>
                        <th>📊 Status</th>
        """
        
        for col in columns:
            table += f"<th>{col.title().replace('_', ' ')}</th>"
        
        table += """
                    </tr>
                </thead>
                <tbody>
        """
        row_num =1
        for metric in metrics:
            status_class = {
                'success': 'status-success',
                'failed': 'status-failed', 
                'partial': 'status-warning'
            }.get(metric.get('status', 'unknown'), 'status-unknown')
            file_path = metric.get('file_path', '#')
            
            table += f"""
                    <tr>
                        <td style="text-align: center; color: #94a3b8; font-weight: 500;">{row_num}</td>
                        <td class="file-name"><a href="{file_path}" target="_blank">{metric.get('file', 'Unknown')}</a></td>
                        <td><span class="status-badge {status_class}">{metric.get('status', 'unknown').title()}</span></td>
            """
            
            for col in columns:
                value = metric.get(col, 'N/A')
                table += f"<td>{value}</td>"
            
            table += "</tr>"
            row_num += 1
        
        table += """
                </tbody>
            </table>
        </div>
        """
        
        return table
    
    def _generate_file_list(self, results: List[ProcessedResult]) -> str:
        """Generate file list items."""
        items = []
        for result in results:
            status_icon = {
                'success': '✅',
                'failed': '❌',
                'partial': '⚠️'
            }.get(result.processing_metadata.get('status', 'unknown'), '❓')
            
            # Count iterations in this file
            iterations = result.data.get('iterations', [])
            iter_count = len(iterations)
            
            items.append(f"""
                <li>
                    {status_icon} <code>{Path(result.file_path).name}</code>
                    <small>({iter_count} iteration{'s' if iter_count != 1 else ''}, {self._format_file_size(result.data.get('file_size', 0))})</small>
                </li>
            """)
        
        return ''.join(items)
    
    def _generate_detailed_results_table(self, results: List[ProcessedResult]) -> str:
        """Generate detailed results table with one row per iteration."""
        return f"""
        <section class="detailed-results">
            <h2>📋 Detailed Results (All Iterations)</h2>
            <div class="table-container">
                <table class="results-table">
                    <thead>
                        <tr>
                            <th>File</th>
                            <th>Config</th>
                            <th>Iteration ID</th>
                            <th>Test Config</th>
                            <th>Benchmark</th>
                            <th>Status</th>
                            <th>Results</th>
                        </tr>
                    </thead>
                    <tbody>
                        {self._generate_results_rows(results)}
                    </tbody>
                </table>
            </div>
        </section>
        """
    
    def _generate_results_rows(self, results: List[ProcessedResult]) -> str:
        """Generate table rows - ONE ROW PER ITERATION (not per file)."""
        rows = []

        for result in results:
            status = result.processing_metadata.get('status', 'unknown')
            status_class = f"status-{status}"
            file_name = Path(result.file_path).name
            # Get common_params from file level
            file_common_params = result.data.get('common_params', {})

            # Get iterations from the data
            iterations = result.data.get('iterations', [])
            
            if not iterations:
                # Fallback: show file-level row if no iterations found
                rows.append(f"""
                    <tr>
                        <td class="file-name"><a href="{result.file_path}" target="_blank">{file_name}</a></td>
                        <td colspan="2"><em>No iterations found</em></td>
                        <td><span class="benchmark-badge">{result.benchmark}</span></td>
                        <td><span class="status-badge {status_class}">{status.title()}</span></td>
                        <td class="key-data">N/A</td>
                    </tr>
                """)
            else:
                # Show ONE ROW per iteration
                for iteration in iterations:
                    iteration_id = iteration.get('iteration_id', 'unknown')
                    unique_params = iteration.get('unique_params', {})
                    iteration_results = iteration.get('results', [])
                    
                    key_tags = result.data.get('key_tags', {})
                    config_str = f"{key_tags.get('pods-per-worker', '?')},{key_tags.get('scale_out_factor', '?')},{key_tags.get('topo', '?')}"
                    rows.append(f"""
                        <tr>
                            <td class="file-name"><a href="{result.file_path}" target="_blank">{file_name}</a></td>
                            <td style="font-size: 0.85rem;">{config_str}</td>  <!-- NEW -->
                            <td><code style="font-size: 0.75rem;">{iteration_id[:8]}...</code></td>
                            <!-- rest of columns -->
                        </tr>
                    """)        
#
                    # Format test configuration - use helper for ALL params
                    config_parts = []
                    
                    protocol = self._get_param_value('protocol', unique_params, file_common_params)
                    
                    # Handle iperf benchmark specially
                    if result.benchmark == 'iperf3' or result.benchmark == 'iperf':
                        max_loss_pct = self._get_param_value('max-loss-pct', unique_params, file_common_params)
                        bitrate_range = self._get_param_value('bitrate-range', unique_params, file_common_params)
                        
                        if max_loss_pct is not None:
                            if protocol:
                                config_parts.append(f"type={protocol}, max-loss-pct={max_loss_pct}")
                            else:
                                config_parts.append(f"type=max-loss-pct={max_loss_pct}")
                        elif bitrate_range:
                            if protocol:
                                config_parts.append(f"type={protocol}, bitrate-range")
                            else:
                                config_parts.append("type=bitrate-range")
                        elif protocol:
                            config_parts.append(f"type={protocol}")

                        length = self._get_param_value('length', unique_params, file_common_params)
                        if length:
                            config_parts.append(f"wsize={length}")
                        # add "special" if there are other passthru params
                        known_params = {'protocol', 'max-loss-pct', 'bitrate-range', 'length', 'nthreads', 
                                        'test-type', 'wsize', 'rsize', 'num_clients','ifname','ipv','time',''}
    
                        has_custom = any(key not in known_params for key in unique_params.keys())
                        if not has_custom:
                            has_custom = any(key not in known_params for key in file_common_params.keys())
    
                        if has_custom:
                            # Find and append to the type= entry
                            for i, part in enumerate(config_parts):
                                if part.startswith('type='):
                                    config_parts[i] += ', special'
                                    break

                    #
                    nthreads = self._get_param_value('nthreads', unique_params, file_common_params)
                    if nthreads:
                        config_parts.append(f"threads={nthreads}")
                    
                    test_type = self._get_param_value('test-type', unique_params, file_common_params)
                    if test_type:
                        if protocol:
                            config_parts.append(f"type={protocol}, {test_type}")
                        else:
                            config_parts.append(f"type={test_type}")
                    
                    wsize = self._get_param_value('wsize', unique_params, file_common_params)
                    if wsize:
                        config_parts.append(f"wsize={wsize}")
                    
                    rsize = self._get_param_value('rsize', unique_params, file_common_params)
                    if rsize:
                        config_parts.append(f"rsize={rsize}")

                    config_str = ", ".join(config_parts) if config_parts else "default"
                    
                    # Format result data - show all results
                    result_str = self._format_iteration_results(iteration_results)
                    
                    rows.append(f"""
                        <tr>
                            <td class="file-name"><a href="{result.file_path}" target="_blank">{file_name}</a></td>
                            <td><code style="font-size: 0.75rem;">{iteration_id[:8]}...</code></td>
                            <td style="font-size: 0.85rem;">{config_str}</td>
                            <td><span class="benchmark-badge">{result.benchmark}</span></td>
                            <td><span class="status-badge {status_class}">{status.title()}</span></td>
                            <td class="key-data">{result_str}</td>
                        </tr>
                    """)
        
        return ''.join(rows)
    
    def _format_iteration_results(self, results_list: List[Dict[str, Any]]) -> str:
        """Format multiple iteration results for display."""
        if not results_list:
            return "N/A"
        
        # Format each result
        formatted_results = []
        for result_data in results_list:
            if not isinstance(result_data, dict):
                continue
            
            parts = []
            
            if 'type' in result_data:
                parts.append(f"<strong>{result_data['type']}</strong>")
            
            if 'mean' in result_data:
                mean = result_data['mean']
                unit = result_data.get('unit', '')
                if isinstance(mean, (int, float)):
                    parts.append(f"{mean:,.2f} {unit}")
                else:
                    parts.append(f"{mean} {unit}")
            
            if 'sample_count' in result_data and result_data['sample_count'] > 1:
                parts.append(f"({result_data['sample_count']} samples)")
            
            if 'stddevpct' in result_data and result_data.get('stddevpct', 0) > 0:
                stddev = result_data['stddevpct']
                if isinstance(stddev, (int, float)):
                    parts.append(f"±{stddev:.1f}%")
            
            if parts:
                formatted_results.append(" ".join(parts))
        
        # Join multiple results with line breaks
        return "<br>".join(formatted_results) if formatted_results else "N/A"
    
    def _generate_charts_section(self, benchmark_data: Dict[str, List[ProcessedResult]]) -> str:
        """Generate charts section."""
        return f"""
        <section class="charts-section">
            <h2>📊 Visual Analysis</h2>
            <div class="charts-container">
                <div class="chart-item">
                    <canvas id="benchmarkChart"></canvas>
                </div>
                <div class="chart-item">
                    <canvas id="statusChart"></canvas>
                </div>
            </div>
        </section>
        """
    
    def _format_file_size(self, size: int) -> str:
        """Format file size in human readable format."""
        if size < 1024:
            return f"{size} B"
        elif size < 1024 * 1024:
            return f"{size / 1024:.1f} KB"
        elif size < 1024 * 1024 * 1024:
            return f"{size / (1024 * 1024):.1f} MB"
        else:
            return f"{size / (1024 * 1024 * 1024):.1f} GB"
    
    def _generate_footer(self) -> str:
        """Generate footer."""
        return f"""
        <footer class="footer">
            <p>Generated by Modular Regulus Report Generator v2.4.0 | 
               <a href="#top">Back to top ↑</a></p>
        </footer>
        """
    
    def _get_css_styles(self) -> str:
        """Get CSS styles for the HTML report."""
        return """
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f8fafc;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px 20px;
            border-radius: 12px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            font-weight: 700;
        }
        
        .icon { font-size: 1.2em; margin-right: 10px; }
        .subtitle { font-size: 1.1rem; opacity: 0.9; }
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .card {
            background: white;
            border-radius: 12px;
            padding: 0;
            box-shadow: 0 4px 15px rgba(0,0,0,0.08);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            overflow: hidden;
        }
        
        .card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0,0,0,0.12);
        }
        
        .card-header {
            padding: 15px 20px 10px;
            border-bottom: 1px solid #e2e8f0;
        }
        
        .card-header h3 {
            font-size: 1rem;
            color: #64748b;
            font-weight: 600;
        }
        
        .card-body {
            padding: 15px 20px 20px;
        }
        
        .metric {
            font-size: 2.5rem;
            font-weight: 700;
            line-height: 1;
            margin-bottom: 5px;
        }
        
        .detail {
            color: #64748b;
            font-size: 0.9rem;
        }
        
        .card.success .metric { color: #10b981; }
        .card.warning .metric { color: #f59e0b; }
        .card.danger .metric { color: #ef4444; }
        .card.info .metric { color: #3b82f6; }
        .card.neutral .metric { color: #6b7280; }
        
        .benchmark-section {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.08);
        }
        
        .benchmark-section h2 {
            color: #1e293b;
            margin-bottom: 15px;
            font-size: 1.5rem;
        }
        
        .benchmark-stats {
            display: flex;
            gap: 20px;
            margin-bottom: 25px;
            flex-wrap: wrap;
        }
        
        .stat {
            background: #f1f5f9;
            padding: 8px 15px;
            border-radius: 20px;
            font-size: 0.9rem;
            font-weight: 500;
        }
        
        .metrics-table-container {
            overflow-x: auto;
            overflow-y: visible;
            margin-bottom: 20px;
            width: 100%;
        }
        
        .metrics-table, .results-table {
            width: max-content;
            min-width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 8px;
            overflow: visible;
        }
        
        .metrics-table th, .results-table th {
            background: #f8fafc;
            padding: 12px 15px;
            text-align: left;
            font-weight: 600;
            color: #374151;
            border-bottom: 2px solid #e5e7eb;
            position: sticky;
            top: 0;
            z-index: 10;
        }
        
        .metrics-table td, .results-table td {
            padding: 10px 15px;
            border-bottom: 1px solid #f3f4f6;
        }
        
        .metrics-table tr:hover, .results-table tr:hover {
            background: #f9fafb;
        }
        
        .file-name {
            font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
            font-size: 0.9rem;
        }
        
        .file-name a {
            color: #6366f1;
            text-decoration: none;
        }
        
        .file-name a:hover {
            text-decoration: underline;
        }
        
        .status-badge {
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 0.8rem;
            font-weight: 500;
            text-transform: uppercase;
        }
        
        .status-success { background: #dcfce7; color: #166534; }
        .status-failed { background: #fee2e2; color: #991b1b; }
        .status-warning { background: #fef3c7; color: #92400e; }
        .status-unknown { background: #f3f4f6; color: #6b7280; }
        
        .benchmark-badge {
            background: #e0e7ff;
            color: #3730a3;
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 0.8rem;
            font-weight: 500;
        }
        
        .file-list {
            margin-top: 20px;
        }
        
        .file-list summary {
            cursor: pointer;
            font-weight: 600;
            color: #4f46e5;
            padding: 10px 0;
        }
        
        .file-list summary:hover {
            color: #4338ca;
        }
        
        .file-list-items {
            list-style: none;
            padding: 15px 0 5px 20px;
        }
        
        .file-list-items li {
            padding: 5px 0;
            color: #6b7280;
        }
        
        .file-list-items code {
            background: #f1f5f9;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 0.85rem;
            color: #1e293b;
        }
        
        .detailed-results {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.08);
        }
        
        .detailed-results h2 {
            margin-bottom: 20px;
            color: #1e293b;
        }
        
        .table-container {
            overflow-x: auto;
            max-height: 800px;
            overflow-y: auto;
        }
        
        .key-data {
            font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
            font-size: 0.85rem;
            color: #4f46e5;
            max-width: 300px;
        }
        
        .charts-section {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.08);
        }
        
        .charts-container {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
        }
        
        .chart-item {
            position: relative;
            height: 300px;
        }
        
        .footer {
            text-align: center;
            padding: 30px;
            color: #64748b;
            border-top: 1px solid #e2e8f0;
            margin-top: 40px;
        }
        
        .footer a {
            color: #4f46e5;
            text-decoration: none;
        }
        
        .footer a:hover {
            text-decoration: underline;
        }
        
        @media (max-width: 768px) {
            .container { padding: 10px; }
            .summary-cards { grid-template-columns: 1fr; }
            .benchmark-stats { flex-direction: column; gap: 10px; }
            .charts-container { grid-template-columns: 1fr; }
        }

       /* Filter input styling */
        #filterInput:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }

        #filterInput.error {
            border-color: #ef4444;
        }

        button:hover {
            background: #475569 !important;
        }

        button:active {
            transform: scale(0.98);
        }

    </style>
        """
    
    def _get_chart_scripts(self) -> str:
        """Get Chart.js script."""
        return """
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        """

    def _get_javascript(self) -> str:
        """Get JavaScript for filtering and charts."""
        return """
<script>
    // Regex Filter Implementation
    const filterInput = document.getElementById('filterInput');
    const matchCount = document.getElementById('matchCount');

    if (filterInput) {
        // Debounced input handler (300ms delay)
        let debounceTimer;
        filterInput.addEventListener('input', function() {
            clearTimeout(debounceTimer);
            debounceTimer = setTimeout(() => {
                filterTables(this.value);
            }, 300);
        });

        // Enter key applies filter immediately
        filterInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
                clearTimeout(debounceTimer);
                filterTables(this.value);
            } else if (e.key === 'Escape') {
                clearFilter();
            }
        });
    }

    function filterTables(pattern) {
        const tables = document.querySelectorAll('.metrics-table, .results-table');
        let totalRows = 0;
        let matchedRows = 0;

        // Clear error state
        filterInput.classList.remove('error');

        if (!pattern) {
            // Show all rows if filter is empty
            tables.forEach(table => {
                const rows = table.querySelectorAll('tbody tr');
                rows.forEach(row => {
                    row.style.display = '';
                    totalRows++;
                });
            });
            matchCount.textContent = '';
            return;
        }

        // Try to create regex, fall back to plain text search if invalid
        let regex;
        let isRegex = true;
        try {
            regex = new RegExp(pattern, 'i');
        } catch (e) {
            isRegex = false;
            filterInput.classList.add('error');
            matchCount.textContent = '⚠️ Invalid regex pattern - using plain text search';
            matchCount.style.color = '#ef4444';
        }

        tables.forEach(table => {
            const rows = table.querySelectorAll('tbody tr');

            rows.forEach(row => {
                totalRows++;
                const text = row.textContent || row.innerText;
                let matches = false;

                if (isRegex) {
                    matches = regex.test(text);
                } else {
                    matches = text.toLowerCase().includes(pattern.toLowerCase());
                }

                if (matches) {
                    row.style.display = '';
                    matchedRows++;
                } else {
                    row.style.display = 'none';
                }
            });
        });

        matchCount.textContent = `Showing ${matchedRows} of ${totalRows} rows`;
        matchCount.style.color = matchedRows === 0 ? '#ef4444' : '#16a34a';
    }

    function clearFilter() {
        filterInput.value = '';
        filterInput.classList.remove('error');
        filterTables('');
    }
</script>
    """

# Enhanced MultiFormatOutputGenerator to include HTML
class EnhancedMultiFormatOutputGenerator(MultiFormatOutputGenerator):
    """Extended multi-format generator with HTML support."""
    
    def __init__(self, schema_manager=None, base_url=''):
        super().__init__(schema_manager)
        self.base_url = base_url
        self.generators['html'] = HtmlOutputGenerator()
        self.generators['csv'] = CsvOutputGenerator(base_url=base_url)
    
    def generate_output(self, results, output_path):
        """Generate output with HTML support."""
        base_path = Path(output_path)
        base_name = base_path.stem
        base_dir = base_path.parent
        
        for format_name in self.enabled_formats:
            if format_name in self.generators:
                try:
                    if format_name == 'html':
                        format_path = base_dir / f"{base_name}.html"
                    elif format_name == 'json':
                        format_path = base_dir / f"{base_name}.json"
                    elif format_name == 'csv':
                        format_path = base_dir / f"{base_name}.csv"
                    elif format_name == 'xml':
                        format_path = base_dir / f"{base_name}.xml"
                    else:
                        format_path = base_dir / f"{base_name}.{format_name}"
                    
                    self.generators[format_name].generate_output(results, str(format_path))
                except Exception as e:
                    print(f"Error generating {format_name} output: {e}")

