"""
Schema version 1.0 definition.

Basic schema with fundamental report structure.
"""

from typing import Dict, Any


def get_v1_0_schema() -> Dict[str, Any]:
    """Get the v1.0 schema definition."""
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "build-report-schema-v1.0.json",
        "title": "Build Report Schema v1.0",
        "description": "Schema for build report summary files",
        "type": "object",
        "required": ["generation_info", "results", "summary_by_benchmark"],
        "properties": {
            "schema_version": {
                "type": "string",
                "const": "1.0"
            },
            "generation_info": {
                "type": "object",
                "required": ["total_results", "timestamp"],
                "properties": {
                    "total_results": {"type": "integer", "minimum": 0},
                    "timestamp": {"type": "string", "format": "date-time"},
                    "benchmarks": {"type": "array", "items": {"type": "string"}},
                    "root_directory": {"type": "string"},
                    "file_pattern": {"type": "string"}
                }
            },
            "results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["file_path", "benchmark"],
                    "properties": {
                        "file_path": {"type": "string"},
                        "benchmark": {"type": "string"},
                        "run-id": {"type": "string"},
                        "result": {"type": ["object", "string", "number"]},
                        "file_size": {"type": "integer"},
                        "file_modified": {"type": "number"}
                    },
                    "additionalProperties": True
                }
            },
            "summary_by_benchmark": {
                "type": "object",
                "patternProperties": {
                    ".*": {
                        "type": "object",
                        "required": ["count", "files"],
                        "properties": {
                            "count": {"type": "integer", "minimum": 0},
                            "files": {"type": "array", "items": {"type": "string"}}
                        }
                    }
                }
            }
        }
    }
