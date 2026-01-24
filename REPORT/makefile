# REPORT/Makefile
# Central makefile for all report-related operations
# Delegates to build_report/Makefile for dashboard and ElasticSearch operations

.PHONY: help summary summary-with-testbed-info dashboard dashboard-stop dashboard-restart \
        flatten flatten-pretty es-upload es-template es-check es-full

# Configuration
PYTHON := python3
BUILD_REPORT_DIR := build_report
REG_ROOT ?= $(shell cd .. && pwd)
ES_HOST ?= localhost:9200
ES_INDEX ?= regulus-results

# Default target
help:
	@echo "====================================================================="
	@echo "  REPORT - Regulus Benchmark Report Generation and Analysis"
	@echo "====================================================================="
	@echo ""
	@echo "Report Generation:"
	@echo "  make summary              - Generate report (unflatten + flatten outputs)"
	@echo "  make summary-with-testbed-info - Generate report with testbed info"
	@echo ""
	@echo "Dashboard & Visualization:"
	@echo "  make dashboard            - Start interactive web dashboard"
	@echo "  make dashboard-stop       - Stop dashboard instances"
	@echo "  make dashboard-restart    - Restart dashboard"
	@echo ""
	@echo "ElasticSearch Integration:"
	@echo "  make flatten              - Flatten existing report.json (or run summary)"
	@echo "  make flatten-pretty       - Create human-readable JSON"
	@echo "  make es-template          - Apply ES index template"
	@echo "  make es-upload            - Upload reports.ndjson to ElasticSearch"
	@echo "  make es-full              - Complete ES workflow (summary → template → upload)"
	@echo ""
	@echo "Configuration:"
	@echo "  REG_ROOT    = $(REG_ROOT)"
	@echo "  ES_HOST     = $(ES_HOST)"
	@echo "  ES_INDEX    = $(ES_INDEX)"
	@echo "====================================================================="

# =============================================================================
# Report Generation Targets
# =============================================================================

summary:
	@echo "Generating unflatten report (report.json, HTML, CSV)..."
	@cd $(REG_ROOT) && bash REPORT/$(BUILD_REPORT_DIR)/build_report --formats html csv --output report
	@echo ""
	@echo "Flattening report.json to NDJSON for ElasticSearch..."
	@$(PYTHON) $(BUILD_REPORT_DIR)/es_integration/flatten_to_es.py $(REG_ROOT)/report.json -o $(REG_ROOT)/reports.ndjson --es-index $(ES_INDEX)
	@echo ""
	@echo "✓ Report generation complete:"
	@echo "  - Unflatten: $(REG_ROOT)/report.json"
	@echo "  - Flatten:   $(REG_ROOT)/reports.ndjson"
	@ls -lh $(REG_ROOT)/report.json $(REG_ROOT)/reports.ndjson 2>/dev/null || true

summary-with-testbed-info:
	@cd $(REG_ROOT) && bash REPORT/assembly/assemble_report.sh

# =============================================================================
# Dashboard Targets (delegate to build_report/Makefile)
# =============================================================================

dashboard:
	@$(MAKE) -C $(BUILD_REPORT_DIR) dashboard REPORTS_DIR=$(REG_ROOT)

dashboard-stop:
	@$(MAKE) -C $(BUILD_REPORT_DIR) dashboard-stop

dashboard-restart:
	@$(MAKE) -C $(BUILD_REPORT_DIR) dashboard-restart

dashboard-status:
	@$(MAKE) -C $(BUILD_REPORT_DIR) dashboard-status

# =============================================================================
# ElasticSearch Targets (delegate to build_report/Makefile)
# =============================================================================

# Flatten report.json to NDJSON format
# Note: 'make summary' already generates both unflatten and flatten outputs
# This target is kept for backward compatibility
flatten:
	@if [ ! -f "$(REG_ROOT)/report.json" ]; then \
		echo "report.json not found. Running 'make summary' to generate both outputs..."; \
		$(MAKE) summary; \
	else \
		echo "Flattening existing report.json..."; \
		$(PYTHON) $(BUILD_REPORT_DIR)/es_integration/flatten_to_es.py $(REG_ROOT)/report.json -o $(REG_ROOT)/reports.ndjson --es-index $(ES_INDEX); \
		echo "✓ Flatten complete: $(REG_ROOT)/reports.ndjson"; \
	fi

# Create human-readable pretty JSON
flatten-pretty: flatten
	@$(MAKE) -C $(BUILD_REPORT_DIR) flatten-pretty OUTPUT_DIR=$(REG_ROOT)

# ElasticSearch operations
es-check:
	@$(MAKE) -C $(BUILD_REPORT_DIR) es-check \
		ES_HOST=$(ES_HOST)

es-template: es-check
	@$(MAKE) -C $(BUILD_REPORT_DIR) es-template \
		ES_HOST=$(ES_HOST)

es-upload:
	@if [ ! -f "$(REG_ROOT)/reports.ndjson" ]; then \
		echo "reports.ndjson not found. Running 'make summary' to generate it..."; \
		$(MAKE) summary; \
	fi
	@$(MAKE) -C $(BUILD_REPORT_DIR) es-upload \
		REPORTS_DIR=$(REG_ROOT) \
		ES_HOST=$(ES_HOST) \
		ES_INDEX=$(ES_INDEX)

# Complete ElasticSearch workflow
es-full: summary es-template es-upload
	@echo ""
	@echo "✓ Complete ElasticSearch workflow finished:"
	@echo "  - Report generated: $(REG_ROOT)/report.json"
	@echo "  - Flattened to: $(REG_ROOT)/reports.ndjson"
	@echo "  - Uploaded to: $(ES_HOST)/$(ES_INDEX)"

# =============================================================================
# Advanced Targets
# =============================================================================

# Clean build artifacts
clean:
	@$(MAKE) -C $(BUILD_REPORT_DIR) clean
	@rm -f $(REG_ROOT)/report.json $(REG_ROOT)/report.html $(REG_ROOT)/report.csv
	@rm -f $(REG_ROOT)/reports.ndjson $(REG_ROOT)/reports_pretty.json
	@echo "✓ Report artifacts cleaned"
