"""
File discovery implementations.

Handles traversing directories and finding target files.
"""

from pathlib import Path
from typing import List, Optional, Tuple

from ..interfaces.protocols import FileDiscoveryInterface
from ..models.data_models import FileInfo


class StandardFileDiscovery:
    """Standard file system discovery implementation."""

    def __init__(self, follow_symlinks: bool = False):
        self.follow_symlinks = follow_symlinks

    def discover_files(self, root_path: str, pattern: str, max_depth: int = 8) -> List[FileInfo]:
        """
        Discover files matching the pattern, limited by max_depth.
        Stops descending into subdirectories once a matching file is found.
        """
        files = []
        root = Path(root_path)
        visited_dirs = set()  # Track directories we've already processed
    
        try:
            # Use os.walk for better control over directory traversal
            import os
            for dirpath, dirnames, filenames in os.walk(root, followlinks=self.follow_symlinks):
                current_dir = Path(dirpath)
                
                # Check depth
                try:
                    relative_depth = len(current_dir.relative_to(root).parts)
                except ValueError:
                    continue
                
                if relative_depth > max_depth:
                    dirnames[:] = []  # Don't descend further
                    continue
                
                # Check if this directory or any parent has already yielded a result
                skip_this_dir = False
                for visited in visited_dirs:
                    if current_dir == visited or visited in current_dir.parents:
                        skip_this_dir = True
                        break
                
                if skip_this_dir:
                    dirnames[:] = []  # Don't descend into subdirectories
                    continue
                
                # Look for matching files in this directory
                for filename in filenames:
                    if Path(filename).match(pattern):
                        file_path = current_dir / filename
                        
                        if file_path.is_file():
                            files.append(FileInfo(
                                path=file_path,
                                size=file_path.stat().st_size,
                                modified_time=file_path.stat().st_mtime
                            ))
                            
                            # Mark this directory as visited
                            visited_dirs.add(current_dir)
                            
                            # Don't descend into subdirectories
                            dirnames[:] = []
                            break  # Stop looking at files in this directory
    
        except Exception as e:
            print(f"Error discovering files: {e}")
    
        return files

class FilteredFileDiscovery:
    """File discovery with additional filtering capabilities."""

    def __init__(self,
                 base_discovery: FileDiscoveryInterface,
                 size_filter: Optional[Tuple[int, int]] = None,
                 date_filter: Optional[Tuple[float, float]] = None):
        self.base_discovery = base_discovery
        self.size_filter = size_filter  # (min_size, max_size)
        self.date_filter = date_filter  # (min_date, max_date)

    def discover_files(self, root_path: str, pattern: str, max_depth: int = 8) -> List[FileInfo]:
        """Discover and filter files."""
        files = self.base_discovery.discover_files(root_path, pattern, max_depth=max_depth)
        return self._apply_filters(files)

    def _apply_filters(self, files: List[FileInfo]) -> List[FileInfo]:
        """Apply configured filters."""
        filtered = files

        if self.size_filter:
            min_size, max_size = self.size_filter
            filtered = [f for f in filtered if min_size <= f.size <= max_size]

        if self.date_filter:
            min_date, max_date = self.date_filter
            filtered = [f for f in filtered if min_date <= f.modified_time <= max_date]

        return filtered


class RegexPatternDiscovery:
    """File discovery using regex patterns for more complex matching."""

    def __init__(self, base_discovery: FileDiscoveryInterface):
        self.base_discovery = base_discovery

    def discover_files_by_regex(self, root_path: str, regex_pattern: str, max_depth: int = 8) -> List[FileInfo]:
        """Discover files using regex pattern on filenames."""
        import re

        # First get all files using a broad pattern
        all_files = self.base_discovery.discover_files(root_path, "*", max_depth=max_depth)

        # Filter by regex
        pattern = re.compile(regex_pattern)
        filtered_files = [f for f in all_files if pattern.search(f.path.name)]

        return filtered_files

