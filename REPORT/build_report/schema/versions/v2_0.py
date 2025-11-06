"""
Schema version 2.0 definition.

Advanced schema with extensible benchmark definitions and full validation support.
"""

from typing import Dict, Any


def get_v2_0_schema() -> Dict[str, Any]:
    """Get the v2.0 schema definition."""
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "build-report-schema-v2.0.json",
        "title": "Build Report Schema v2.0",
        "description": "Advanced schema with extensible benchmark definitions",
        "type": "object",
        "required": ["schema_info", "generation_info", "results", "summary_by_benchmark"],
        "properties": {
            "schema_info": {
                "type": "object",
                "required": ["version", "description"],
                "properties": {
                    "version": {"type": "string", "const": "2.0"},
                    "description": {"type": "string"},
                    "created_date": {"type": "string", "format": "date"},
                    "last_modified": {"type": "string", "format": "date"}
                }
            },
            "generation_info": {
                "type": "object",
                "required": ["total_results", "successful_results", "timestamp"],
                "properties": {
                    "total_results": {"type": "integer", "minimum": 0},
                    "successful_results": {"type": "integer", "minimum": 0},
                    "failed_results": {"type": "integer", "minimum": 0},
                    "timestamp": {"type": "string", "format": "date-time"},
                    "benchmarks": {"type": "array", "items": {"type": "string"}},
                    "root_directory": {"type": "string"},
                    "file_pattern": {"type": "string"},
                    "processing_duration_seconds": {"type": "number", "minimum": 0}
                }
            },
            "benchmark_definitions": {
                "type": "object",
                "description": "Schema definitions for each benchmark type",
                "patternProperties": {
                    ".*": {
                        "type": "object",
                        "properties": {
                            "description": {"type": "string"},
                            "required_fields": {"type": "array", "items": {"type": "string"}},
                            "optional_fields": {"type": "array", "items": {"type": "string"}},
                            "field_schemas": {
                                "type": "object",
                                "description": "JSON Schema definitions for specific fields"
                            },
                            "result_format": {"type": "string", "enum": ["simple", "structured", "time_series"]},
                            "validation_rules": {"type": "array", "items": {"type": "string"}}
                        }
                    }
                }
            },
            "results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["file_path", "benchmark", "processing_status"],
                    "properties": {
                        "file_path": {"type": "string"},
                        "benchmark": {"type": "string"},
                        "processing_status": {"type": "string", "enum": ["success", "partial", "failed", "skipped"]},
                        "run-id": {"type": "string"},
                        "result": {"type": ["object", "string", "number", "array"]},
                        "file_metadata": {
                            "type": "object",
                            "properties": {
                                "size_bytes": {"type": "integer"},
                                "modified_timestamp": {"type": "number"},
                                "encoding": {"type": "string"},
                                "line_count": {"type": "integer"}
                            }
                        },
                        "extraction_metadata": {
                            "type": "object",
                            "properties": {
                                "rules_applied": {"type": "array", "items": {"type": "string"}},
                                "fields_extracted": {"type": "integer"},
                                "extraction_duration_ms": {"type": "number"}
                            }
                        }
                    },
                    "additionalProperties": True
                }
            },
            "summary_by_benchmark": {
                "type": "object",
                "patternProperties": {
                    ".*": {
                        "type": "object",
                        "required": ["count", "files", "success_rate"],
                        "properties": {
                            "count": {"type": "integer", "minimum": 0},
                            "successful_count": {"type": "integer", "minimum": 0},
                            "failed_count": {"type": "integer", "minimum": 0},
                            "success_rate": {"type": "number", "minimum": 0, "maximum": 1},
                            "files": {"type": "array", "items": {"type": "string"}},
                            "avg_processing_time_ms": {"type": "number", "minimum": 0},
                            "field_coverage": {"type": "object"}
                        }
                    }
                }
            },
            "validation_report": {
                "type": "object",
                "properties": {
                    "schema_validation": {"type": "boolean"},
                    "validation_errors": {"type": "array", "items": {"type": "string"}},
                    "validation_warnings": {"type": "array", "items": {"type": "string"}},
                    "data_quality_score": {"type": "number", "minimum": 0, "maximum": 1}
                }
            }
        }
    }


def get_trafficgen_benchmark_schema() -> Dict[str, Any]:
    """Get specific schema for trafficgen benchmark results."""
    return {
        "type": "object",
        "required": ["type", "mean"],
        "properties": {
            "type": {
                "type": "string",
                "description": "Type of measurement (e.g., rx-pps, tx-pps)"
            },
            "samples": {
                "type": "number",
                "minimum": 0,
                "description": "Number of samples"
            },
            "mean": {
                "type": "number",
                "minimum": 0,
                "description": "Mean value"
            },
            "min": {
                "type": "number",
                "minimum": 0,
                "description": "Minimum value"
            },
            "max": {
                "type": "number",
                "minimum": 0,
                "description": "Maximum value"
            },
            "stddev": {
                "type": ["number", "null"],
                "minimum": 0,
                "description": "Standard deviation"
            }
        }
    }


def get_benchmark_specific_schemas() -> Dict[str, Dict[str, Any]]:
    """Get schema definitions for specific benchmark types."""
    return {
        "trafficgen": {
            "description": "Network traffic generation benchmark",
            "required_fields": ["file_path", "benchmark", "run-id", "result"],
            "optional_fields": ["period_length", "tags", "iteration-id", "sample-id", "period_range"],
            "field_schemas": {
                "result": get_trafficgen_benchmark_schema(),
                "period_length": {
                    "type": "string",
                    "pattern": r"^[0-9.]+\s*(seconds?|s|ms|milliseconds?)$"
                },
                "run-id": {
                    "type": "string",
                    "pattern": r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
                }
            },
            "result_format": "structured",
            "validation_rules": [
                "result.mean > 0",
                "result.min <= result.mean <= result.max"
            ]
        },
        "iperf": {
            "description": "Network performance testing with iPerf",
            "required_fields": ["file_path", "benchmark", "bandwidth"],
            "optional_fields": ["duration", "protocol", "parallel_streams"],
            "field_schemas": {
                "bandwidth": {
                    "type": "object",
                    "properties": {
                        "value": {"type": "number", "minimum": 0},
                        "unit": {"type": "string", "enum": ["bps", "Kbps", "Mbps", "Gbps"]}
                    }
                }
            },
            "result_format": "structured"
        },
        "fio": {
            "description": "Storage I/O performance testing",
            "required_fields": ["file_path", "benchmark", "iops"],
            "optional_fields": ["bandwidth", "latency", "block_size"],
            "field_schemas": {
                "iops": {"type": "number", "minimum": 0},
                "latency": {
                    "type": "object",
                    "properties": {
                        "mean": {"type": "number", "minimum": 0},
                        "p95": {"type": "number", "minimum": 0},
                        "p99": {"type": "number", "minimum": 0}
                    }
                }
            },
            "result_format": "structured"
        }
    }
