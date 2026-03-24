"""
File browser routes - List directories and read files.
Supports both local filesystem paths and HTTP/HTTPS URLs (if requests/beautifulsoup4 installed).
"""

import os
import re
from pathlib import Path
from urllib.parse import urljoin, urlparse
from flask import Blueprint, request, jsonify

# Optional HTTP support - only if libraries are installed
try:
    import requests
    from bs4 import BeautifulSoup
    HTTP_SUPPORT = True
except ImportError:
    HTTP_SUPPORT = False

file_browser_bp = Blueprint('file_browser', __name__, url_prefix='/api')


def is_http_url(path):
    """Check if path is an HTTP/HTTPS URL."""
    return path.startswith('http://') or path.startswith('https://')


def join_path(base, relative):
    """Join base and relative path, handling both URLs and file paths."""
    if is_http_url(base):
        # Use URL joining for HTTP URLs
        # Remove leading slash from relative path for proper joining
        relative_clean = relative.lstrip('/')
        # Ensure base ends with /
        if not base.endswith('/'):
            base = base + '/'
        return urljoin(base, relative_clean)
    else:
        # Use os.path.join for local paths
        return os.path.normpath(os.path.join(base, relative.lstrip('/')))


def list_http_directory(url):
    """List directory contents from HTTP server."""
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()

        # Parse HTML to find links
        soup = BeautifulSoup(response.text, 'html.parser')
        items = []

        for link in soup.find_all('a'):
            href = link.get('href')
            if not href or href.startswith('?') or href.startswith('#'):
                continue

            # Skip parent directory links
            if href == '../':
                continue

            name = link.text.strip() or href

            # Determine if directory (usually ends with /)
            is_dir = href.endswith('/')

            # Clean up name
            if is_dir:
                name = name.rstrip('/')
                href = href.rstrip('/')

            items.append({
                'name': name,
                'href': href,
                'is_directory': is_dir
            })

        return items
    except Exception as e:
        raise Exception(f"Failed to list HTTP directory: {str(e)}")


def read_http_file(url):
    """Read file contents from HTTP server."""
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        return response.text, len(response.content)
    except Exception as e:
        raise Exception(f"Failed to read HTTP file: {str(e)}")


def init_file_browser_routes():
    """Initialize file browser routes."""

    @file_browser_bp.route('/list_directory', methods=['POST'])
    def api_list_directory():
        """List contents of a directory (local or HTTP)."""
        try:
            data = request.json or {}
            regulus_root = data.get('regulus_root', '')
            relative_path = data.get('path', '')

            if not regulus_root:
                return jsonify({
                    'success': False,
                    'error': 'Regulus root path not configured'
                }), 400

            # Construct full path (handles both URLs and file paths)
            full_path = join_path(regulus_root, relative_path)

            # Handle HTTP URLs
            if is_http_url(regulus_root):
                if not HTTP_SUPPORT:
                    return jsonify({
                        'success': False,
                        'error': 'HTTP URL support requires additional libraries. Install with: pip install requests beautifulsoup4'
                    }), 400

                try:
                    # Ensure URL ends with / for directory listing
                    if not full_path.endswith('/'):
                        full_path = full_path + '/'

                    http_items = list_http_directory(full_path)

                    # Convert to standard format
                    items = []
                    for item in http_items:
                        # Construct full relative path
                        if relative_path:
                            item_rel_path = relative_path.rstrip('/') + '/' + item['href']
                        else:
                            item_rel_path = item['href']

                        items.append({
                            'name': item['name'],
                            'path': item_rel_path,
                            'is_directory': item['is_directory'],
                            'size': None  # Size not available from HTML listing
                        })

                    # Sort: directories first, then files, both alphabetically
                    items.sort(key=lambda x: (not x['is_directory'], x['name'].lower()))

                    return jsonify({
                        'success': True,
                        'path': relative_path,
                        'items': items
                    })

                except Exception as e:
                    return jsonify({
                        'success': False,
                        'error': f'HTTP error: {str(e)}'
                    }), 500

            # Handle local filesystem paths
            else:
                # Security: ensure path is within regulus_root
                norm_root = os.path.normpath(regulus_root)
                if not full_path.startswith(norm_root):
                    return jsonify({
                        'success': False,
                        'error': 'Access denied: path outside regulus root'
                    }), 403

                # Check if directory exists
                if not os.path.exists(full_path):
                    return jsonify({
                        'success': False,
                        'error': f'Directory not found: {full_path}'
                    }), 404

                if not os.path.isdir(full_path):
                    return jsonify({
                        'success': False,
                        'error': 'Path is not a directory'
                    }), 400

                # List directory contents
                items = []
                try:
                    for entry in os.listdir(full_path):
                        entry_path = os.path.join(full_path, entry)
                        is_dir = os.path.isdir(entry_path)

                        # Get relative path from regulus root
                        rel_path = os.path.relpath(entry_path, regulus_root)

                        items.append({
                            'name': entry,
                            'path': rel_path,
                            'is_directory': is_dir,
                            'size': os.path.getsize(entry_path) if not is_dir else None
                        })
                except PermissionError:
                    return jsonify({
                        'success': False,
                        'error': 'Permission denied'
                    }), 403

                # Sort: directories first, then files, both alphabetically
                items.sort(key=lambda x: (not x['is_directory'], x['name'].lower()))

                return jsonify({
                    'success': True,
                    'path': relative_path,
                    'items': items
                })

        except Exception as e:
            import traceback
            return jsonify({
                'success': False,
                'error': str(e),
                'traceback': traceback.format_exc()
            }), 500

    @file_browser_bp.route('/read_file', methods=['POST'])
    def api_read_file():
        """Read contents of a file (local or HTTP)."""
        try:
            data = request.json or {}
            regulus_root = data.get('regulus_root', '')
            relative_path = data.get('path', '')

            if not regulus_root:
                return jsonify({
                    'success': False,
                    'error': 'Regulus root path not configured'
                }), 400

            # Construct full path (handles both URLs and file paths)
            full_path = join_path(regulus_root, relative_path)

            # Handle HTTP URLs
            if is_http_url(regulus_root):
                if not HTTP_SUPPORT:
                    return jsonify({
                        'success': False,
                        'error': 'HTTP URL support requires additional libraries. Install with: pip install requests beautifulsoup4'
                    }), 400

                try:
                    content, file_size = read_http_file(full_path)

                    # Check file size (limit to 10MB)
                    if file_size > 10 * 1024 * 1024:
                        return jsonify({
                            'success': False,
                            'error': f'File too large: {file_size / (1024*1024):.1f}MB (max 10MB)'
                        }), 400

                    return jsonify({
                        'success': True,
                        'path': relative_path,
                        'content': content,
                        'size': file_size
                    })

                except Exception as e:
                    return jsonify({
                        'success': False,
                        'error': f'HTTP error: {str(e)}'
                    }), 500

            # Handle local filesystem paths
            else:
                # Security: ensure path is within regulus_root
                norm_root = os.path.normpath(regulus_root)
                if not full_path.startswith(norm_root):
                    return jsonify({
                        'success': False,
                        'error': 'Access denied: path outside regulus root'
                    }), 403

                # Check if file exists
                if not os.path.exists(full_path):
                    return jsonify({
                        'success': False,
                        'error': f'File not found: {full_path}'
                    }), 404

                if not os.path.isfile(full_path):
                    return jsonify({
                        'success': False,
                        'error': 'Path is not a file'
                    }), 400

                # Check file size (limit to 10MB)
                file_size = os.path.getsize(full_path)
                if file_size > 10 * 1024 * 1024:
                    return jsonify({
                        'success': False,
                        'error': f'File too large: {file_size / (1024*1024):.1f}MB (max 10MB)'
                    }), 400

                # Read file contents
                try:
                    with open(full_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                except UnicodeDecodeError:
                    # Try binary mode if UTF-8 fails
                    with open(full_path, 'rb') as f:
                        content = f.read().decode('utf-8', errors='replace')

                return jsonify({
                    'success': True,
                    'path': relative_path,
                    'content': content,
                    'size': file_size
                })

        except Exception as e:
            import traceback
            return jsonify({
                'success': False,
                'error': str(e),
                'traceback': traceback.format_exc()
            }), 500

    return file_browser_bp
