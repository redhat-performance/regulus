"""
Data models for the build report generator.

Contains all dataclasses and enums used throughout the system.
"""

from dataclasses import dataclass, asdict, field
from enum import Enum
from pathlib import Path
from typing import Dict, List, Any, Optional
import datetime


class SchemaVersion(Enum):
    """Supported schema versions."""
    V1_0 = "1.0"
    V1_1 = "1.1"
    V2_0 = "2.0"


class ResultStatus(Enum):
    """Status of result processing."""
    SUCCESS = "success"
    PARTIAL = "partial"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class FileInfo:
    """Information about a discovered file."""
    path: Path
    size: int
    modified_time: float


@dataclass
class ExtractionRule:
    """A single extraction rule."""
    field_name: str
    pattern: str
    processor: Optional[str] = None  # Optional post-processing function name


@dataclass
class BenchmarkRuleSet:
    """Set of rules for a specific benchmark."""
    benchmark_name: str
    rules: List[ExtractionRule]
    metadata_rules: Optional[List[ExtractionRule]] = None


@dataclass
class ExtractedData:
    """Raw extracted data from a file."""
    file_info: FileInfo
    benchmark: str
    raw_matches: Dict[str, Any]
    extraction_metadata: Dict[str, Any]


@dataclass
class ProcessedResult:
    """Processed and transformed result."""
    file_path: str
    benchmark: str
    data: Dict[str, Any]
    processing_metadata: Dict[str, Any]


@dataclass
class SchemaInfo:
    """Schema metadata."""
    version: str
    description: str
    created_date: str
    last_modified: str
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return asdict(self)


# ============================================================================
# NEW CLASSES FOR MULTI-ITERATION SUPPORT
# ============================================================================

@dataclass
class TestIteration:
    """
    Represents a single test iteration within a benchmark run.
    
    Each iteration has:
    - A unique iteration_id (UUID from the result file)
    - Unique parameters that differentiate it from other iterations
    - Multiple samples (individual test runs)
    - Multiple results (can have uperf AND iperf results in same iteration)
    """
    iteration_id: str
    unique_params: Dict[str, str] = field(default_factory=dict)
    samples: List[Dict[str, Any]] = field(default_factory=list)
    results: List[Dict[str, Any]] = field(default_factory=list)  # CHANGED: Now a list!
    
    def __repr__(self):
        return f"TestIteration(id={self.iteration_id[:8]}..., params={self.unique_params}, samples={len(self.samples)}, results={len(self.results)})"


@dataclass
class MultiResultExtractedData:
    """
    Extracted data that contains multiple iterations.
    
    This replaces single-result extraction with a structure that can
    handle 1 to N iterations per file.
    """
    file_info: FileInfo
    benchmark: str
    run_id: str
    common_params: Dict[str, str]
    iterations: List[TestIteration]  # List of all iterations
    extraction_metadata: Dict[str, Any] = field(default_factory=dict)
    raw_matches: Dict[str, Any] = field(default_factory=dict)  # For backward compatibility
    
    def __repr__(self):
        return f"MultiResultExtractedData(file={self.file_info.path.name}, benchmark={self.benchmark}, iterations={len(self.iterations)})"
