"""
Factory functions for creating different orchestrator configurations.
"""

from .models.data_models import SchemaVersion
from .discovery.file_discovery import StandardFileDiscovery, FilteredFileDiscovery
from .parsing.content_parser import TextFileParser, CachingParser
from .rules.rule_engine import ConfigurableRuleEngine
from .extraction.data_extractor import RegexDataExtractor
from .transformation.data_transformer import StandardDataTransformer
from .output.generators import SchemaAwareOutputGenerator
from .schema.schema_manager import SchemaManager
from .orchestration.orchestrator import (
    ReportOrchestrator, BatchReportOrchestrator, ParallelReportOrchestrator
)


def create_default_orchestrator():
    """Create orchestrator with default components."""
    schema_manager = SchemaManager(SchemaVersion.V2_0)
    return ReportOrchestrator(
        file_discovery=StandardFileDiscovery(),
        content_parser=TextFileParser(),
        rule_engine=ConfigurableRuleEngine(),
        data_extractor=RegexDataExtractor(),
        data_transformer=StandardDataTransformer(),
        output_generator=SchemaAwareOutputGenerator(schema_manager)
    )


def create_enhanced_orchestrator(schema_version=SchemaVersion.V2_0,
                               with_caching=True,
                               with_filtering=False,
                               parallel=False,
                               max_workers=4):
    """Create orchestrator with enhanced configuration."""
    schema_manager = SchemaManager(schema_version)
    
    # Configure file discovery
    file_discovery = StandardFileDiscovery()
    if with_filtering:
        file_discovery = FilteredFileDiscovery(
            file_discovery,
            size_filter=(100, 50*1024*1024)  # 100 bytes to 50MB
        )
    
    # Configure parser
    parser = TextFileParser()
    if with_caching:
        parser = CachingParser(parser)
    
    # Create orchestrator
    orchestrator_class = ParallelReportOrchestrator if parallel else ReportOrchestrator
    kwargs = {'max_workers': max_workers} if parallel else {}
    
    return orchestrator_class(
        file_discovery=file_discovery,
        content_parser=parser,
        rule_engine=ConfigurableRuleEngine(),
        data_extractor=RegexDataExtractor(enable_timing=True),
        data_transformer=StandardDataTransformer(),
        output_generator=SchemaAwareOutputGenerator(schema_manager),
        **kwargs
    )


def create_batch_orchestrator():
    """Create orchestrator for batch processing."""
    schema_manager = SchemaManager(SchemaVersion.V2_0)
    return BatchReportOrchestrator(
        file_discovery=StandardFileDiscovery(),
        content_parser=CachingParser(TextFileParser()),
        rule_engine=ConfigurableRuleEngine(),
        data_extractor=RegexDataExtractor(enable_timing=True),
        data_transformer=StandardDataTransformer(),
        output_generator=SchemaAwareOutputGenerator(schema_manager)
    )

def create_html_orchestrator(schema_version=SchemaVersion.V2_0):
    """Create orchestrator with HTML output."""
    from .output.generators import HtmlOutputGenerator
    
    schema_manager = SchemaManager(schema_version)
    return ReportOrchestrator(
        file_discovery=StandardFileDiscovery(),
        content_parser=TextFileParser(),
        rule_engine=ConfigurableRuleEngine(),
        data_extractor=RegexDataExtractor(),
        data_transformer=StandardDataTransformer(),
        output_generator=HtmlOutputGenerator()  # HTML instead of JSON
    )

def create_multi_format_orchestrator(formats=['json', 'html']):
    """Create orchestrator with multiple output formats."""
    from .output.generators import EnhancedMultiFormatOutputGenerator
    
    schema_manager = SchemaManager(SchemaVersion.V2_0)
    multi_generator = EnhancedMultiFormatOutputGenerator(schema_manager)
    
    # Enable specified formats
    for fmt in formats:
        multi_generator.enable_format(fmt)
    
    return ReportOrchestrator(
        file_discovery=StandardFileDiscovery(),
        content_parser=TextFileParser(),
        rule_engine=ConfigurableRuleEngine(),
        data_extractor=RegexDataExtractor(),
        data_transformer=StandardDataTransformer(),
        output_generator=multi_generator
    )

