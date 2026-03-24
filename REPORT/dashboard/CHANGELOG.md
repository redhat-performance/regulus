# Dashboard Changelog

All notable changes to the Performance Benchmark Dashboard.

## [1.1.0] - 2025-03-24

### Added

#### File Browser & Source Viewer
- **File Browser Drawer**: Browse artifact directories and view source files
  - Slides in from right side (resizable, 300px-80% width)
  - Click benchmark badge in Results Table to open
  - Navigate directories with breadcrumbs and parent (..) links
  - View text files directly in browser
  - Copy file contents to clipboard
  - Preserves scroll position when navigating back from file view

- **HTTP URL Support** (optional):
  - Browse artifacts on remote HTTP/HTTPS servers
  - Parses HTML directory listings
  - Requires optional dependencies: `requests`, `beautifulsoup4`
  - Gracefully falls back to local-only if libraries not installed

- **Settings Configuration**:
  - Configure Regulus Root Path for artifact access
  - Supports both local filesystem paths and HTTP URLs
  - Persists to browser localStorage
  - Accessible via ⚙️ Settings button in navbar

#### Enhanced Filtering
- **Multi-select Report Files**:
  - Select one or more report files to display
  - Ctrl+Click to select multiple files
  - Collapsible section to save space
  - Handles dozens of report files efficiently

- **Collapsible Filter Sections**:
  - Report Files section is collapsible (starts collapsed)
  - Date Range section is collapsible (starts collapsed)
  - Toggle icons (▼/▲) rotate on expand/collapse
  - Consistent look and feel for both sections

#### UI Improvements
- **Resizable File Browser**:
  - Drag left edge to resize drawer
  - Min width: 300px, Max width: 80% of screen
  - Width preference saved to localStorage
  - Subtle hover effect on resize handle

- **Main Content Sliding**:
  - Dashboard slides left when drawer opens (no overlap)
  - Horizontal scrollbar appears if content is too wide
  - Smooth CSS transitions

- **Clickable Benchmark Badges**:
  - Blue benchmark badges now clickable to open file browser
  - Tooltip shows full artifact path
  - Clean, single-button UI (no extra links)

### Changed
- Report Files filter increased from 3 to 4-5 visible items
- Date Range filter now matches Report Files styling
- File browser shows 5 files when expanded (up from 3)

### Fixed
- Fixed broken import in `__init__.py` (removed reference to deleted `dashboard_app.py`)
- File browser "Back" button now preserves scroll position instead of reloading
- HTTP URL path joining no longer mangles `http://` → `http:/`

### Technical Details

#### New Dependencies (Optional)
- `requests>=2.31.0` - For HTTP artifact browsing
- `beautifulsoup4>=4.12.0` - For parsing HTML directory listings

#### New API Endpoints
- `POST /api/list_directory` - List directory contents (local or HTTP)
- `POST /api/read_file` - Read file contents (local or HTTP)
- `GET /api/list_files` - List all available report files with metadata

#### New Files
- `api/file_browser_routes.py` - File browser backend routes
- CSS for drawer, resize handle, collapsible sections
- JavaScript for file navigation, resizing, localStorage

#### Architecture Updates
- Modular file browser with local/HTTP abstraction
- Security: Path validation prevents directory traversal
- File size limit: 10MB max for viewing
- Browser localStorage for user preferences (regulus root, drawer width)

## [1.0.0] - 2025-11-17

### Added - Initial Release

#### Core Features
- **Multi-Report Aggregation**: Load and analyze multiple JSON reports simultaneously
- **Interactive Web UI**: Bootstrap 5-based responsive dashboard
- **Four Main Views**: Overview, Trends, Comparison, Results Table
- **Advanced Filtering**: Filter by benchmark, model, kernel, topology, performance baseline
- **REST API**: 8 endpoints for programmatic access

#### Data Processing
- **ReportLoader** (`data_loader.py`):
  - Load single or multiple JSON reports
  - Extract benchmark results from nested structure
  - Filter results by various criteria
  - Support for multi-iteration and multi-result data

- **BenchmarkAggregator** (`aggregator.py`):
  - Time-series trend analysis with grouping
  - Side-by-side configuration comparison
  - Statistical aggregations (mean, median, stddev, min, max)
  - Top performers analysis
  - Configuration matrix generation

#### Web Application
- **Flask Backend** (`dashboard_app.py`):
  - Flask web server with template rendering
  - 8 REST API endpoints
  - Absolute path resolution for templates and static files
  - Directory validation on startup
  - Debug output for troubleshooting

- **Frontend** (`templates/dashboard.html`, `static/dashboard.js`):
  - Summary statistics cards
  - Interactive charts with Chart.js
  - DataTables for sortable/searchable results
  - Real-time filtering across all views
  - Responsive design for mobile/desktop

#### API Endpoints
- `GET /api/summary` - Overall statistics
- `GET /api/results` - All results with filtering
- `GET /api/trends` - Time-series trend data
- `GET /api/compare` - Side-by-side comparison
- `GET /api/statistics` - Statistics grouped by field
- `GET /api/top_performers` - Top N performing results
- `GET /api/matrix` - Configuration performance matrix
- `GET /api/filters` - Available filter options
- `POST /api/reload` - Reload reports without restart

#### CLI
- **Command-line Interface** (`run_dashboard.py`):
  - Launch with custom reports directory
  - Configurable host and port
  - Debug mode support
  - Help and usage information

- **Launcher Script** (`launch_dashboard`):
  - Bash wrapper for easy execution
  - Automatic PYTHONPATH configuration

#### Documentation
- **README.md**: Complete feature documentation
- **QUICKSTART.md**: Step-by-step getting started guide
- **USAGE_GUIDE.md**: Comprehensive usage documentation
- **CHANGELOG.md**: This file
- **requirements.txt**: Python dependencies

#### Data Models
- `BenchmarkResult`: Single test iteration result
- `ReportMetadata`: Report file metadata
- `TrendDataPoint`: Time-series data point
- `ComparisonResult`: Configuration comparison result

#### Visualizations
- **Bar Charts**: Performance by model/kernel
- **Line Charts**: Time-series trends with grouping
- **Tables**: Top performers and detailed results
- **Summary Cards**: Quick statistics overview

### Fixed

#### Template Path Resolution
- Fixed `TemplateNotFound` error when running from different directories
- Added absolute path resolution using `Path(__file__).resolve().parent`
- Added directory existence validation on startup
- Added debug output showing template and static folder paths

#### Import Compatibility
- Added fallback imports for relative/absolute imports
- Works when run as module or standalone script
- Compatible with Python 3.6+

### Technical Details

#### Dependencies
- **Python**: 3.6 or higher
- **Flask**: 2.0 or higher (tested with 2.0.3)
- **Frontend Libraries** (CDN):
  - Bootstrap 5.3.0
  - Chart.js 4.4.0
  - jQuery 3.7.0
  - DataTables 1.13.6

#### Architecture
- **Pattern**: MVC (Model-View-Controller)
- **Data Flow**: JSON Reports → Loader → Aggregator → API → Frontend
- **Design**: Protocol-based with dependency injection
- **Structure**: Modular components for easy extension

#### Performance
- Loads all data into memory (suitable for hundreds of reports)
- Single-threaded Flask development server
- Caching support in data loader
- Efficient aggregation algorithms

### Known Limitations

1. **Development Server**: Uses Flask's built-in server (not for production)
2. **Memory Usage**: All reports loaded into memory
3. **No Persistence**: Data reloaded on each restart
4. **No Authentication**: No user authentication/authorization
5. **Single-threaded**: One request at a time

### Future Enhancements

Planned features for future releases:

- [ ] Production-ready deployment (Gunicorn/uWSGI)
- [ ] Database backend (SQLite/PostgreSQL)
- [ ] Persistent storage of loaded reports
- [ ] User authentication and multi-user support
- [ ] Real-time report monitoring (file watchers)
- [ ] Export charts as images (PNG/SVG)
- [ ] Export filtered data to CSV
- [ ] Custom metric calculations
- [ ] Anomaly detection
- [ ] Alert system for performance regressions
- [ ] Historical comparison across date ranges
- [ ] Dashboard configuration persistence
- [ ] Advanced filtering (regex, ranges)
- [ ] Custom report templates
- [ ] Integration with CI/CD pipelines

### Credits

Created for the Regulus/Crucible Performance Benchmark Report Generator.

### License

[Add license information]

---

## Version History

- **1.0.0** (2025-11-17): Initial release with core features
