"""
Schema management for the build report generator.

Handles schema definitions, validation, and version management.
"""

import json
from typing import Dict, Any, Optional, Tuple

from ..interfaces.protocols import SchemaManagerInterface
from ..models.data_models import SchemaVersion, SchemaInfo
from .versions.v1_0 import get_v1_0_schema
from .versions.v1_1 import get_v1_1_schema  
from .versions.v2_0 import get_v2_0_schema

try:
    from jsonschema import validate, ValidationError
    JSONSCHEMA_AVAILABLE = True
except ImportError:
    JSONSCHEMA_AVAILABLE = False
    print("Warning: jsonschema not available. Schema validation disabled.")


class SchemaManager:
    """Manages report schemas and validation."""
    
    def __init__(self, schema_version: SchemaVersion = SchemaVersion.V2_0):
        self.schema_version = schema_version
        self.schemas = self._initialize_schemas()
    
    def _initialize_schemas(self) -> Dict[str, Dict[str, Any]]:
        """Initialize all supported schemas."""
        return {
            SchemaVersion.V1_0.value: get_v1_0_schema(),
            SchemaVersion.V1_1.value: get_v1_1_schema(),
            SchemaVersion.V2_0.value: get_v2_0_schema()
        }
    
    def get_schema(self, version: str = None) -> Dict[str, Any]:
        """Get schema for specified version."""
        version = version or self.schema_version.value
        return self.schemas.get(version, self.schemas[SchemaVersion.V1_0.value])
    
    def validate_report(self, report_data: Dict[str, Any], version: str = None) -> Tuple[bool, Optional[str]]:
        """Validate report against schema."""
        if not JSONSCHEMA_AVAILABLE:
            return True, "Schema validation skipped (jsonschema not available)"
        
        schema = self.get_schema(version)
        try:
            validate(instance=report_data, schema=schema)
            return True, None
        except ValidationError as e:
            return False, str(e)
    
    def export_schema(self, output_path: str, version: str = None) -> None:
        """Export schema to JSON file."""
        schema = self.get_schema(version)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(schema, f, indent=2)
        print(f"Schema exported to: {output_path}")
    
    def get_schema_info(self, version: str = None) -> SchemaInfo:
        """Get schema metadata information."""
        version = version or self.schema_version.value
        info_map = {
            SchemaVersion.V1_0.value: SchemaInfo(
                version="1.0",
                description="Initial build report schema with basic result structure",
                created_date="2025-01-01",
                last_modified="2025-01-01"
            ),
            SchemaVersion.V1_1.value: SchemaInfo(
                version="1.1",
                description="Enhanced schema with benchmark-specific fields and metadata",
                created_date="2025-01-01",
                last_modified="2025-01-15"
            ),
            SchemaVersion.V2_0.value: SchemaInfo(
                version="2.0",
                description="Advanced schema with extensible benchmark definitions and validation",
                created_date="2025-01-01",
                last_modified="2025-01-20"
            )
        }
        return info_map.get(version, info_map[SchemaVersion.V1_0.value])
    
    def list_available_versions(self) -> list[str]:
        """List all available schema versions."""
        return list(self.schemas.keys())
    
    def upgrade_report(self, report_data: Dict[str, Any], target_version: str) -> Dict[str, Any]:
        """Upgrade a report to a newer schema version."""
        current_version = report_data.get('schema_info', {}).get('version', '1.0')
        
        if current_version == target_version:
            return report_data
        
        # Implement version-specific upgrade logic
        if current_version == '1.0' and target_version == '1.1':
            return self._upgrade_v1_0_to_v1_1(report_data)
        elif current_version == '1.1' and target_version == '2.0':
            return self._upgrade_v1_1_to_v2_0(report_data)
        elif current_version == '1.0' and target_version == '2.0':
            # Multi-step upgrade
            intermediate = self._upgrade_v1_0_to_v1_1(report_data)
            return self._upgrade_v1_1_to_v2_0(intermediate)
        
        return report_data  # No upgrade path found
    
    def _upgrade_v1_0_to_v1_1(self, report_data: Dict[str, Any]) -> Dict[str, Any]:
        """Upgrade report from v1.0 to v1.1."""
        upgraded = report_data.copy()
        
        # Add schema version
        upgraded['schema_version'] = '1.1'
        
        # Add processing metadata if missing
        if 'processing_metadata' not in upgraded:
            upgraded['processing_metadata'] = [
                {
                    'transformation_time': '',
                    'processors_used': [],
                    'status': 'success'
                }
                for _ in upgraded.get('results', [])
            ]
        
        return upgraded
    
    def _upgrade_v1_1_to_v2_0(self, report_data: Dict[str, Any]) -> Dict[str, Any]:
        """Upgrade report from v1.1 to v2.0."""
        upgraded = report_data.copy()
        
        # Replace schema_version with schema_info
        if 'schema_version' in upgraded:
            del upgraded['schema_version']
        
        upgraded['schema_info'] = self.get_schema_info('2.0').to_dict()
        
        # Enhance generation_info
        gen_info = upgraded.get('generation_info', {})
        results = upgraded.get('results', [])
        
        gen_info.update({
            'successful_results': len([r for r in results if r.get('processing_status') == 'success']),
            'failed_results': len([r for r in results if r.get('processing_status') == 'failed']),
            'processing_duration_seconds': 0.0
        })
        
        # Add validation_report if missing
        if 'validation_report' not in upgraded:
            upgraded['validation_report'] = {
                'schema_validation': True,
                'validation_errors': [],
                'validation_warnings': [],
                'data_quality_score': 1.0
            }
        
        return upgraded
    
    def validate_field_definitions(self, benchmark_definitions: Dict[str, Any]) -> Dict[str, list]:
        """Validate benchmark field definitions."""
        validation_results = {}
        
        for benchmark_name, definition in benchmark_definitions.items():
            errors = []
            
            # Check required fields
            if 'required_fields' not in definition:
                errors.append("Missing required_fields definition")
            
            if 'optional_fields' not in definition:
                errors.append("Missing optional_fields definition")
            
            # Validate field schemas if present
            if 'field_schemas' in definition:
                for field_name, field_schema in definition['field_schemas'].items():
                    if not isinstance(field_schema, dict):
                        errors.append(f"Invalid schema for field {field_name}")
            
            validation_results[benchmark_name] = errors
        
        return validation_results


class DynamicSchemaManager(SchemaManager):
    """Schema manager with dynamic schema modification capabilities."""
    
    def __init__(self, schema_version: SchemaVersion = SchemaVersion.V2_0):
        super().__init__(schema_version)
        self.custom_schemas = {}
    
    def add_custom_schema(self, version_name: str, schema: Dict[str, Any]) -> bool:
        """Add a custom schema version."""
        try:
            # Validate that it's a proper JSON schema
            if '$schema' not in schema:
                schema['$schema'] = "https://json-schema.org/draft/2020-12/schema"
            
            self.custom_schemas[version_name] = schema
            return True
        except Exception as e:
            print(f"Error adding custom schema {version_name}: {e}")
            return False
    
    def get_schema(self, version: str = None) -> Dict[str, Any]:
        """Get schema, including custom schemas."""
        version = version or self.schema_version.value
        
        # Check custom schemas first
        if version in self.custom_schemas:
            return self.custom_schemas[version]
        
        # Fall back to standard schemas
        return super().get_schema(version)
    
    def extend_schema(self, base_version: str, extension: Dict[str, Any], new_version: str) -> bool:
        """Extend an existing schema with additional properties."""
        try:
            base_schema = self.get_schema(base_version).copy()
            
            # Merge properties
            if 'properties' in extension:
                if 'properties' not in base_schema:
                    base_schema['properties'] = {}
                base_schema['properties'].update(extension['properties'])
            
            # Merge required fields
            if 'required' in extension:
                if 'required' not in base_schema:
                    base_schema['required'] = []
                base_schema['required'].extend(extension['required'])
            
            # Update metadata
            base_schema['$id'] = f"build-report-schema-{new_version}.json"
            base_schema['title'] = f"Build Report Schema {new_version}"
            
            self.custom_schemas[new_version] = base_schema
            return True
            
        except Exception as e:
            print(f"Error extending schema: {e}")
            return False
    
    def list_available_versions(self) -> list[str]:
        """List all available schema versions including custom ones."""
        standard_versions = super().list_available_versions()
        custom_versions = list(self.custom_schemas.keys())
        return standard_versions + custom_versions

