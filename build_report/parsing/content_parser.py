"""
Content parsing implementations.

Handles reading and parsing file contents with various strategies.
"""

from typing import Optional, Dict, Any

from ..interfaces.protocols import ContentParserInterface
from ..models.data_models import FileInfo


class TextFileParser:
    """Simple text file parser."""
    
    def __init__(self, encoding: str = 'utf-8', error_handling: str = 'ignore'):
        self.encoding = encoding
        self.error_handling = error_handling
    
    def parse_file(self, file_info: FileInfo) -> Optional[str]:
        """Parse text file content."""
        try:
            with open(file_info.path, 'r', encoding=self.encoding, errors=self.error_handling) as f:
                return f.read()
        except Exception as e:
            print(f"Error parsing file {file_info.path}: {e}")
            return None


class CachingParser:
    """Parser with caching capabilities."""
    
    def __init__(self, base_parser: ContentParserInterface):
        self.base_parser = base_parser
        self._cache: Dict[tuple, str] = {}
    
    def parse_file(self, file_info: FileInfo) -> Optional[str]:
        """Parse file with caching based on modification time."""
        cache_key = (str(file_info.path), file_info.modified_time)
        
        if cache_key in self._cache:
            return self._cache[cache_key]
        
        content = self.base_parser.parse_file(file_info)
        if content is not None:
            self._cache[cache_key] = content
        
        return content
    
    def clear_cache(self) -> None:
        """Clear the parser cache."""
        self._cache.clear()
    
    def get_cache_stats(self) -> Dict[str, Any]:
        """Get cache statistics."""
        return {
            "cache_size": len(self._cache),
            "memory_usage_estimate": sum(len(content) for content in self._cache.values())
        }


class MultiEncodingParser:
    """Parser that tries multiple encodings."""
    
    def __init__(self, encodings: list[str] = None):
        self.encodings = encodings or ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']
    
    def parse_file(self, file_info: FileInfo) -> Optional[str]:
        """Parse file trying multiple encodings."""
        for encoding in self.encodings:
            try:
                with open(file_info.path, 'r', encoding=encoding) as f:
                    content = f.read()
                print(f"Successfully parsed {file_info.path} with encoding: {encoding}")
                return content
            except UnicodeDecodeError:
                continue
            except Exception as e:
                print(f"Error parsing file {file_info.path} with {encoding}: {e}")
                continue
        
        print(f"Failed to parse {file_info.path} with any encoding")
        return None


class BinaryAwareParser:
    """Parser that can handle binary files and extract text."""
    
    def __init__(self, fallback_parser: ContentParserInterface):
        self.fallback_parser = fallback_parser
    
    def parse_file(self, file_info: FileInfo) -> Optional[str]:
        """Parse file, detecting binary content."""
        try:
            # Read a sample to detect binary content
            with open(file_info.path, 'rb') as f:
                sample = f.read(1024)
            
            # Simple binary detection
            if b'\x00' in sample:
                print(f"Binary file detected: {file_info.path}")
                return self._extract_text_from_binary(file_info)
            
            # Use fallback parser for text files
            return self.fallback_parser.parse_file(file_info)
            
        except Exception as e:
            print(f"Error in binary-aware parsing {file_info.path}: {e}")
            return None
    
    def _extract_text_from_binary(self, file_info: FileInfo) -> Optional[str]:
        """Extract text from binary files (basic implementation)."""
        try:
            with open(file_info.path, 'rb') as f:
                content = f.read()
            
            # Simple text extraction - remove non-printable chars
            text = ''.join(chr(b) for b in content if 32 <= b <= 126 or b in [9, 10, 13])
            return text if text.strip() else None
            
        except Exception as e:
            print(f"Error extracting text from binary {file_info.path}: {e}")
            return None

