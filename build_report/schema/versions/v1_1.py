"""
Schema version 1.1 definition.

Enhanced schema with benchmark-specific fields and metadata.
"""

from typing import Dict, Any
from .v1_0 import get_v1_0_schema


def get_v1_1_schema() -> Dict[str, Any]:
    """Get the v1.1 schema definition."""
    base_schema = get_v1_0_schema()
    base_schema.update({
        "$id": "build-report-schema-v1.1.json",
        "title": "Build Report Schema v1.1",
        "properties": {
            **base_schema["properties"],
            "schema_version": {"type": "string", "const": "1.1"},
            "benchmark_definitions": {
                "type": "object",
                "description": "Definitions of expected fields per benchmark",
                "patternProperties": {
                    ".*": {
                        "type": "object",
                        "properties": {
                            "required_fields": {"type": "array", "items": {"type": "string"}},
                            "optional_fields": {"type": "array", "items": {"type": "string"}},
                            "field_types": {"type": "object"}
                        }
                    }
                }
            },
            "processing_metadata": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "transformation_time": {"type": "string", "format": "date-time"},
                        "processors_used": {"type": "array", "items": {"type": "string"}},
                        "status": {"type": "string", "enum": ["success", "partial", "failed", "skipped"]}
                    }
                }
            }
        }
    })
    return base_schema
