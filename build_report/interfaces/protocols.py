"""
Protocol interfaces for the build report generator.

Defines the contracts that each module must implement.
"""

from typing import Dict, List, Any, Optional, Protocol
from ..models.data_models import (
    FileInfo, BenchmarkRuleSet, ExtractedData, ProcessedResult
)


class FileDiscoveryInterface(Protocol):
    """Interface for file discovery components."""
    
    def discover_files(self, root_path: str, pattern: str) -> List[FileInfo]:
        """Discover files matching the pattern."""
        ...


class ContentParserInterface(Protocol):
    """Interface for content parsing components."""
    
    def parse_file(self, file_info: FileInfo) -> Optional[str]:
        """Parse file content and return as string."""
        ...


class RuleEngineInterface(Protocol):
    """Interface for rule management components."""
    
    def get_rules_for_benchmark(self, benchmark: str) -> BenchmarkRuleSet:
        """Get rules for a specific benchmark."""
        ...
    
    def add_benchmark_rules(self, ruleset: BenchmarkRuleSet) -> None:
        """Add or update rules for a benchmark."""
        ...


class DataExtractorInterface(Protocol):
    """Interface for data extraction components."""
    
    def extract_data(self, content: str, rules: BenchmarkRuleSet, file_info: FileInfo) -> ExtractedData:
        """Extract data from content using rules."""
        ...


class DataTransformerInterface(Protocol):
    """Interface for data transformation components."""
    
    def transform_data(self, extracted_data: ExtractedData) -> ProcessedResult:
        """Transform extracted data into final format."""
        ...


class OutputGeneratorInterface(Protocol):
    """Interface for output generation components."""
    
    def generate_output(self, results: List[ProcessedResult], output_path: str) -> None:
        """Generate final output file."""
        ...


class SchemaManagerInterface(Protocol):
    """Interface for schema management components."""
    
    def get_schema(self, version: str = None) -> Dict[str, Any]:
        """Get schema for specified version."""
        ...
    
    def validate_report(self, report_data: Dict[str, Any], version: str = None) -> tuple[bool, Optional[str]]:
        """Validate report against schema."""
        ...
    
    def export_schema(self, output_path: str, version: str = None) -> None:
        """Export schema to JSON file."""
        ...
