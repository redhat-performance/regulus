"""
Report orchestrator - coordinates all components.

Manages the entire report generation workflow using dependency injection.
"""

import re
import time
from typing import List

from ..interfaces.protocols import (
    FileDiscoveryInterface, ContentParserInterface, RuleEngineInterface,
    DataExtractorInterface, DataTransformerInterface, OutputGeneratorInterface
)
from ..models.data_models import ProcessedResult


class ReportOrchestrator:
    """Orchestrates the entire report generation process."""
    
    def __init__(self,
                 file_discovery: FileDiscoveryInterface,
                 content_parser: ContentParserInterface,
                 rule_engine: RuleEngineInterface,
                 data_extractor: DataExtractorInterface,
                 data_transformer: DataTransformerInterface,
                 output_generator: OutputGeneratorInterface):
        self.file_discovery = file_discovery
        self.content_parser = content_parser
        self.rule_engine = rule_engine
        self.data_extractor = data_extractor
        self.data_transformer = data_transformer
        self.output_generator = output_generator
        
        # Configuration options
        self.enable_progress = True
        self.enable_timing = True
        self.continue_on_error = True
        
        # Statistics tracking
        self.stats = {
            'files_discovered': 0,
            'files_processed': 0,
            'files_failed': 0,
            'total_duration': 0.0,
            'avg_processing_time': 0.0
        }
    
    def generate_report(self, root_path: str = ".", 
                       file_pattern: str = "result-summary.txt",
                       output_path: str = "summary-all.json") -> None:
        """Generate the complete report."""
        start_time = time.time() if self.enable_timing else None
        
        if self.enable_progress:
            print("Starting modular report generation...")
        
        # Step 1: Discover files
        files = self.file_discovery.discover_files(root_path, file_pattern)
        self.stats['files_discovered'] = len(files)
        
        if self.enable_progress:
            print(f"Discovered {len(files)} files")
        
        if not files:
            print("No files found!")
            return
        
        results = []
        file_times = []
        
        # Step 2: Process each file
        for i, file_info in enumerate(files):
            if self.enable_progress and len(files) > 10:
                if i % max(1, len(files) // 10) == 0:
                    print(f"Processing file {i+1}/{len(files)}...")
            
            try:
                file_start_time = time.time() if self.enable_timing else None
                
                # Parse content
                content = self.content_parser.parse_file(file_info)
                if content is None:
                    self.stats['files_failed'] += 1
                    if not self.continue_on_error:
                        raise Exception(f"Failed to parse {file_info.path}")
                    continue
                
                # Extract benchmark type to get appropriate rules
                benchmark_match = re.search(r"benchmark:\s*(.+)", content)
                benchmark = benchmark_match.group(1).strip() if benchmark_match else "default"
                
                # Get rules and extract data
                rules = self.rule_engine.get_rules_for_benchmark(benchmark)
                extracted_data = self.data_extractor.extract_data(content, rules, file_info)
                
                # Transform data
                processed_result = self.data_transformer.transform_data(extracted_data)
                results.append(processed_result)
                
                self.stats['files_processed'] += 1
                
                if self.enable_timing:
                    file_duration = time.time() - file_start_time
                    file_times.append(file_duration)
                
            except Exception as e:
                self.stats['files_failed'] += 1
                if self.enable_progress:
                    print(f"Error processing {file_info.path}: {e}")
                
                if not self.continue_on_error:
                    raise
        
        # Update statistics
        if self.enable_timing:
            self.stats['total_duration'] = time.time() - start_time
            if file_times:
                self.stats['avg_processing_time'] = sum(file_times) / len(file_times)
        
        # Step 3: Generate output
        self.output_generator.generate_output(results, output_path)
        
        # Print summary
        if self.enable_progress:
            self._print_summary()
    
    def _print_summary(self):
        """Print processing summary."""
        print(f"\n{'='*60}")
        print("PROCESSING SUMMARY")
        print(f"{'='*60}")
        print(f"Files discovered: {self.stats['files_discovered']}")
        print(f"Files processed: {self.stats['files_processed']}")
        print(f"Files failed: {self.stats['files_failed']}")
        
        if self.stats['files_discovered'] > 0:
            success_rate = (self.stats['files_processed'] / self.stats['files_discovered']) * 100
            print(f"Success rate: {success_rate:.1f}%")
        
        if self.enable_timing and self.stats['total_duration'] > 0:
            print(f"Total duration: {self.stats['total_duration']:.2f} seconds")
            print(f"Average processing time: {self.stats['avg_processing_time']*1000:.1f} ms/file")
        
        print(f"{'='*60}")
    
    def get_statistics(self) -> dict:
        """Get current processing statistics."""
        return self.stats.copy()
    
    def reset_statistics(self):
        """Reset processing statistics."""
        self.stats = {
            'files_discovered': 0,
            'files_processed': 0,
            'files_failed': 0,
            'total_duration': 0.0,
            'avg_processing_time': 0.0
        }
    
    def configure(self, **options):
        """Configure orchestrator options."""
        for key, value in options.items():
            if hasattr(self, key):
                setattr(self, key, value)
            else:
                print(f"Warning: Unknown configuration option: {key}")


class BatchReportOrchestrator(ReportOrchestrator):
    """Extended orchestrator for batch processing multiple directories."""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.batch_results = {}
    
    def generate_batch_reports(self, directories: List[str], 
                             file_pattern: str = "result-summary.txt",
                             output_prefix: str = "batch") -> None:
        """Generate reports for multiple directories."""
        print(f"Starting batch processing for {len(directories)} directories...")
        
        for i, directory in enumerate(directories):
            print(f"\nProcessing directory {i+1}/{len(directories)}: {directory}")
            
            output_path = f"{output_prefix}_{i+1}_summary.json"
            
            try:
                self.generate_report(directory, file_pattern, output_path)
                self.batch_results[directory] = {
                    'status': 'success',
                    'output_file': output_path,
                    'stats': self.get_statistics()
                }
            except Exception as e:
                print(f"Error processing directory {directory}: {e}")
                self.batch_results[directory] = {
                    'status': 'failed',
                    'error': str(e),
                    'stats': self.get_statistics()
                }
            
            # Reset stats for next directory
            self.reset_statistics()
        
        self._generate_batch_summary(output_prefix)
    
    def _generate_batch_summary(self, output_prefix: str):
        """Generate a summary of batch processing results."""
        summary_file = f"{output_prefix}_batch_summary.json"
        
        import json
        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump(self.batch_results, f, indent=2)
        
        print(f"\nBatch summary generated: {summary_file}")
        
        # Print batch statistics
        successful = sum(1 for r in self.batch_results.values() if r['status'] == 'success')
        failed = len(self.batch_results) - successful
        
        print(f"Batch processing complete:")
        print(f"  Successful: {successful}")
        print(f"  Failed: {failed}")
        print(f"  Total directories: {len(self.batch_results)}")


class ParallelReportOrchestrator(ReportOrchestrator):
    """Orchestrator with parallel processing capabilities."""
    
    def __init__(self, *args, max_workers: int = 4, **kwargs):
        super().__init__(*args, **kwargs)
        self.max_workers = max_workers
    
    def generate_report(self, root_path: str = ".", 
                       file_pattern: str = "result-summary.txt",
                       output_path: str = "summary-all.json") -> None:
        """Generate report with parallel file processing."""
        try:
            from concurrent.futures import ThreadPoolExecutor, as_completed
        except ImportError:
            print("Warning: concurrent.futures not available, falling back to sequential processing")
            super().generate_report(root_path, file_pattern, output_path)
            return
        
        start_time = time.time() if self.enable_timing else None
        
        if self.enable_progress:
            print(f"Starting parallel report generation (workers: {self.max_workers})...")
        
        # Step 1: Discover files
        files = self.file_discovery.discover_files(root_path, file_pattern)
        self.stats['files_discovered'] = len(files)
        
        if self.enable_progress:
            print(f"Discovered {len(files)} files")
        
        if not files:
            print("No files found!")
            return
        
        results = []
        
        # Step 2: Process files in parallel
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            # Submit all file processing tasks
            future_to_file = {
                executor.submit(self._process_single_file, file_info): file_info 
                for file_info in files
            }
            
            # Collect results as they complete
            for future in as_completed(future_to_file):
                file_info = future_to_file[future]
                try:
                    result = future.result()
                    if result is not None:
                        results.append(result)
                        self.stats['files_processed'] += 1
                    else:
                        self.stats['files_failed'] += 1
                except Exception as e:
                    self.stats['files_failed'] += 1
                    if self.enable_progress:
                        print(f"Error processing {file_info.path}: {e}")
                    
                    if not self.continue_on_error:
                        raise
                
                # Progress update
                if self.enable_progress and len(files) > 10:
                    completed = self.stats['files_processed'] + self.stats['files_failed']
                    if completed % max(1, len(files) // 10) == 0:
                        print(f"Completed {completed}/{len(files)} files...")
        
        # Update timing
        if self.enable_timing:
            self.stats['total_duration'] = time.time() - start_time
        
        # Step 3: Generate output
        self.output_generator.generate_output(results, output_path)
        
        # Print summary
        if self.enable_progress:
            self._print_summary()
    
    def _process_single_file(self, file_info) -> ProcessedResult:
        """Process a single file (for parallel execution)."""
        # Parse content
        content = self.content_parser.parse_file(file_info)
        if content is None:
            return None
        
        # Extract benchmark type to get appropriate rules
        benchmark_match = re.search(r"benchmark:\s*(.+)", content)
        benchmark = benchmark_match.group(1).strip() if benchmark_match else "default"
        
        # Get rules and extract data
        rules = self.rule_engine.get_rules_for_benchmark(benchmark)
        extracted_data = self.data_extractor.extract_data(content, rules, file_info)
        
        # Transform data
        processed_result = self.data_transformer.transform_data(extracted_data)
        return processed_result

