# REPORT Directory Restructure Plan

## Problem Statement

Currently:
- `dashboard/`, `es_integration/`, and `mcp_server/` are under `build_report/`
- These are peer tools/components, NOT part of the core report builder
- This creates architectural confusion and dependency issues

## Target Structure

```
$REG_ROOT/REPORT/
├── build_report/          # CORE: Report builder ONLY
│   ├── discovery/
│   ├── extraction/
│   ├── interfaces/
│   ├── models/
│   ├── orchestration/
│   ├── output/
│   ├── parsing/
│   ├── rules/
│   ├── schema/
│   └── transformation/
├── dashboard/             # TOOL: Web visualization (MOVED from build_report/)
├── es_integration/        # TOOL: ES upload (MOVED from build_report/)
├── mcp_server/            # TOOL: MCP interface (MOVED from build_report/)
└── assembly/              # TOOL: Testbed info merger (already at correct level)
```

## Components to Move

### 1. dashboard/
**From:** `$REG_ROOT/REPORT/build_report/dashboard/`
**To:** `$REG_ROOT/REPORT/dashboard/`

**Files:**
- `run_dashboard.py` - Main CLI entry point
- `data_loader.py` - Loads report.json, parses benchmark results
- `__init__.py` - Package initialization, Flask app factory
- `templates/` - Jinja2 HTML templates
- `static/` - JS, CSS assets
- `test_data/` - Sample reports for testing

**Dependencies:**
- Uses `data_loader.BenchmarkResult` dataclass
- Flask app reads from `REPORTS_DIR` (configurable path)
- **Critical:** `data_loader.py` needs to share `BenchmarkResult` with `es_integration/`

### 2. es_integration/
**From:** `$REG_ROOT/REPORT/build_report/es_integration/`
**To:** `$REG_ROOT/REPORT/es_integration/`

**Files:**
- `flatten_to_es.py` - Converts report.json to NDJSON for ES
- `es_mapping_template.json` - ES index mapping
- `opensearch_mapping_template.json` - OpenSearch variant
- `ES-README.md` - User guide
- `README.md` - Technical notes

**Dependencies:**
- Uses `dashboard.data_loader.BenchmarkResult` to parse report.json
- Outputs to `$REG_ROOT/reports.ndjson` (configurable)

### 3. mcp_server/
**From:** `$REG_ROOT/REPORT/build_report/mcp_server/`
**To:** `$REG_ROOT/REPORT/mcp_server/`

**Files:**
- `regulus_es_mcp.py` - MCP server with ES tools
- `es_cli.py` - CLI wrapper
- `es_show_keywords.py` - Keyword display
- `Dockerfile`, `requirements.txt`
- `build_and_run.sh`, `show_keywords.sh`
- `README.md`, `QUICKSTART.md`, etc.

**Dependencies:**
- Standalone - queries ES directly via HTTP
- No Python dependencies on other REPORT components

## Impact Analysis

### Python Import Changes

#### dashboard/data_loader.py
**Before (as submodule of build_report):**
```python
# No changes needed - standalone module
```

**After (as peer to build_report):**
```python
# Still standalone - no changes needed
```

#### es_integration/flatten_to_es.py
**Before:**
```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
from dashboard.data_loader import BenchmarkResult, ReportLoader
```

**After:**
```python
import sys
from pathlib import Path
# Add parent (REPORT/) to path to access sibling modules
sys.path.insert(0, str(Path(__file__).parent.parent))
from dashboard.data_loader import BenchmarkResult, ReportLoader
```
*Actually NO CHANGE needed - already uses parent directory!*

#### build_report/build_report (main CLI)
**Before:**
- Imports from submodules: `discovery/`, `extraction/`, etc.
- No imports from `dashboard/` or `es_integration/`

**After:**
- Same - no changes needed
- Build report is isolated from tools

### Makefile Changes

#### $REG_ROOT/REPORT/makefile
**Current responsibilities:**
- Delegates to `build_report/makefile` for report generation
- Delegates to `build_report/makefile` for dashboard, flatten, ES operations

**New responsibilities:**
- Delegates to `build_report/makefile` ONLY for report generation
- Handles dashboard, es_integration, mcp_server directly (no delegation to build_report)

**Changes needed:**
```makefile
# Dashboard targets
dashboard:
    @cd dashboard && python run_dashboard.py --reports $(REG_ROOT) ...

dashboard-stop:
    @pkill -f "run_dashboard.py" || true

# ES integration targets
flatten:
    @cd es_integration && python flatten_to_es.py ...

es-upload:
    @cd es_integration && curl ...

# Build report (delegate to build_report/)
summary:
    @$(MAKE) -C build_report summary
```

#### $REG_ROOT/REPORT/build_report/makefile
**Current responsibilities:**
- Report generation (summary, HTML, CSV)
- Dashboard (run, stop, restart)
- ES integration (flatten, upload, template, batch management)

**New responsibilities:**
- Report generation ONLY (summary, HTML, CSV)
- Remove all dashboard targets
- Remove all ES integration targets

**Changes needed:**
- Remove `.PHONY` entries for dashboard, es-*, etc.
- Remove all dashboard targets
- Remove all es-* targets
- Keep only report generation targets

#### $REG_ROOT/makefile (root level)
**Current:**
- Delegates `report-*` targets to `REPORT/makefile`

**After:**
- No changes needed - still delegates to `REPORT/makefile`
- `REPORT/makefile` handles the new structure internally

### Path Dependencies

#### REG_ROOT Usage
All three tools (dashboard, es_integration, mcp_server) can use `REG_ROOT` environment variable:

**dashboard/run_dashboard.py:**
```python
reports_dir = os.getenv('REG_ROOT', os.getcwd())
```

**es_integration/flatten_to_es.py:**
```python
# Input: report.json path (passed as argument or defaults to REG_ROOT/report.json)
# Output: reports.ndjson path (defaults to REG_ROOT/reports.ndjson)
```

**mcp_server/:**
- Container-based, no REG_ROOT dependency
- Queries ES directly via network

## Migration Steps

### Phase 1: Preparation (No code changes)
1. ✅ Create this plan document
2. ⏳ Review with team
3. ⏳ Backup current state: `git stash` or create branch

### Phase 2: Move Directories
```bash
cd $REG_ROOT/REPORT

# Move components to peer level
git mv build_report/dashboard ./
git mv build_report/es_integration ./
git mv build_report/mcp_server ./
```

### Phase 3: Update Makefiles
1. Update `REPORT/makefile`:
   - Move dashboard targets from build_report to REPORT level
   - Move ES targets from build_report to REPORT level
   - Update paths: `dashboard/` instead of `build_report/dashboard/`

2. Update `REPORT/build_report/makefile`:
   - Remove dashboard targets
   - Remove ES targets
   - Keep only core report generation

3. Verify `$REG_ROOT/makefile`:
   - Should need no changes (delegates to REPORT/)

### Phase 4: Update Python Imports
1. Check `dashboard/data_loader.py` - likely no changes needed
2. Check `es_integration/flatten_to_es.py`:
   - Verify sys.path manipulation still works
   - Test import of `dashboard.data_loader`

3. Update documentation references

### Phase 5: Update Documentation
1. `REPORT/README.md` - Update directory structure diagrams
2. `REPORT/build_report/README.md` - Remove tool documentation
3. `REPORT/dashboard/README.md` - Update paths
4. `REPORT/es_integration/ES-README.md` - Update paths
5. `REPORT/mcp_server/README.md` - Update paths

### Phase 6: Testing
1. Test report generation:
   ```bash
   cd $REG_ROOT
   make report-summary
   ```

2. Test dashboard:
   ```bash
   cd $REG_ROOT
   make report-dashboard
   ```

3. Test ES integration:
   ```bash
   cd $REG_ROOT
   make report-flatten
   make report-es-upload
   ```

4. Test MCP server:
   ```bash
   cd $REG_ROOT/REPORT/mcp_server
   ./build_and_run.sh list-batches
   ```

## Rollback Plan

If issues arise:
```bash
cd $REG_ROOT/REPORT

# Revert moves
git mv dashboard build_report/
git mv es_integration build_report/
git mv mcp_server build_report/

# Revert makefile changes
git checkout REPORT/makefile
git checkout build_report/makefile
```

## Benefits of New Structure

1. **Clear Separation of Concerns:**
   - `build_report/` = Core report generation engine
   - `dashboard/`, `es_integration/`, `mcp_server/` = Peer tools that consume reports

2. **Simplified Dependencies:**
   - Tools at same level can import from each other naturally
   - No nested module confusion

3. **Better Extensibility:**
   - Easy to add new peer tools (e.g., `grafana_integration/`)
   - Tools can be developed/maintained independently

4. **Cleaner Makefiles:**
   - `build_report/makefile` focuses on core generation
   - `REPORT/makefile` orchestrates all tools

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Broken Python imports | HIGH | Careful sys.path testing, isolated testing |
| Makefile target breakage | HIGH | Comprehensive testing of all targets |
| Documentation outdated | MEDIUM | Update all docs in Phase 5 |
| User workflow disruption | MEDIUM | Keep root-level targets working (make report-*) |

## Timeline Estimate

- Phase 1 (Plan review): 30 minutes
- Phase 2 (Move dirs): 5 minutes
- Phase 3 (Makefiles): 30-45 minutes
- Phase 4 (Python imports): 15 minutes
- Phase 5 (Documentation): 30 minutes
- Phase 6 (Testing): 30 minutes

**Total:** ~2.5-3 hours

## Open Questions

1. Should `assembly/` also be restructured? (Currently already peer to build_report)
2. Do any external scripts reference `build_report/dashboard` paths?
3. Are there CI/CD pipelines that need updating?

## Next Steps

1. Get approval for this plan
2. Create feature branch: `git checkout -b restructure-report-tools`
3. Execute phases 2-6
4. Create PR with comprehensive testing documentation
