# REPORT/Makefile
# Central makefile for all report-related operations
# Delegates to build_report/Makefile for dashboard and ElasticSearch operations

.PHONY: help summary summary-with-testbed-info dashboard dashboard-stop dashboard-restart \
        flatten flatten-pretty es-upload es-template es-check es-full

# Configuration
PYTHON := python3
BUILD_REPORT_DIR := build_report
REPORT_DIR := $(shell pwd)
GENERATED_DIR := $(REPORT_DIR)/generated
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
	@echo "Creating generated directory if needed..."
	@mkdir -p $(GENERATED_DIR)
	@# Backup report-with-testbed-info.json if it exists (to avoid dashboard duplicates)
	@if [ -f "$(GENERATED_DIR)/report-with-testbed-info.json" ]; then \
		echo "Backing up report-with-testbed-info.json to report-with-testbed-info.json.bak"; \
		mv -f "$(GENERATED_DIR)/report-with-testbed-info.json" "$(GENERATED_DIR)/report-with-testbed-info.json.bak"; \
	fi
	@echo "Generating unflatten report (report.json, HTML, CSV) in REPORT/generated/..."
	@cd $(REG_ROOT) && bash REPORT/$(BUILD_REPORT_DIR)/build_report --formats html csv --output REPORT/generated/report
	@echo ""
	@echo "Flattening report.json to NDJSON for ElasticSearch..."
	@$(PYTHON) $(BUILD_REPORT_DIR)/es_integration/flatten_to_es.py $(GENERATED_DIR)/report.json -o $(GENERATED_DIR)/reports.ndjson --es-index $(ES_INDEX)
	@echo ""
	@echo "✓ Report generation complete:"
	@echo "  - Unflatten: $(GENERATED_DIR)/report.json"
	@echo "  - Flatten:   $(GENERATED_DIR)/reports.ndjson"
	@ls -lh $(GENERATED_DIR)/report.json $(GENERATED_DIR)/reports.ndjson 2>/dev/null || true

summary-with-testbed-info:
	@cd $(REG_ROOT) && bash REPORT/assembly/assemble_report.sh

# =============================================================================
# Dashboard Targets (delegate to build_report/Makefile)
# =============================================================================

dashboard:
	@$(MAKE) -C $(BUILD_REPORT_DIR) dashboard REPORTS_DIR=$(GENERATED_DIR)

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
	@mkdir -p $(GENERATED_DIR)
	@if [ ! -f "$(GENERATED_DIR)/report.json" ]; then \
		echo "report.json not found. Running 'make summary' to generate both outputs..."; \
		$(MAKE) summary; \
	else \
		echo "Flattening existing report.json..."; \
		$(PYTHON) $(BUILD_REPORT_DIR)/es_integration/flatten_to_es.py $(GENERATED_DIR)/report.json -o $(GENERATED_DIR)/reports.ndjson --es-index $(ES_INDEX); \
		echo "✓ Flatten complete: $(GENERATED_DIR)/reports.ndjson"; \
	fi

# Create human-readable pretty JSON
flatten-pretty: flatten
	@$(MAKE) -C $(BUILD_REPORT_DIR) flatten-pretty OUTPUT_DIR=$(GENERATED_DIR)

# ElasticSearch operations
es-check:
	@[ -f "$(REG_ROOT)/lab.config" ] && source $(REG_ROOT)/lab.config; \
	$(MAKE) -C $(BUILD_REPORT_DIR) es-check \
		ES_HOST=$${ES_HOST:-$(ES_HOST)} \
		ES_USER=$${ES_USER} \
		ES_PASSWORD=$${ES_PASSWORD}

es-template: es-check
	@[ -f "$(REG_ROOT)/lab.config" ] && source $(REG_ROOT)/lab.config; \
	$(MAKE) -C $(BUILD_REPORT_DIR) es-template \
		ES_HOST=$${ES_HOST:-$(ES_HOST)} \
		ES_USER=$${ES_USER} \
		ES_PASSWORD=$${ES_PASSWORD}

es-upload:
	@if [ ! -f "$(GENERATED_DIR)/reports.ndjson" ]; then \
		echo "reports.ndjson not found. Running 'make summary' to generate it..."; \
		$(MAKE) summary; \
	fi
	@[ -f "$(REG_ROOT)/lab.config" ] && source $(REG_ROOT)/lab.config; \
	$(MAKE) -C $(BUILD_REPORT_DIR) es-upload \
		REPORTS_DIR=$(GENERATED_DIR) \
		ES_HOST=$${ES_HOST:-$(ES_HOST)} \
		ES_INDEX=$${ES_INDEX:-$(ES_INDEX)} \
		ES_USER=$${ES_USER} \
		ES_PASSWORD=$${ES_PASSWORD}

# Complete ElasticSearch workflow
es-full: summary es-template es-upload
	@echo ""
	@echo "✓ Complete ElasticSearch workflow finished:"
	@echo "  - Report generated: $(GENERATED_DIR)/report.json"
	@echo "  - Flattened to: $(GENERATED_DIR)/reports.ndjson"
	@echo "  - Uploaded to: $(ES_HOST)/$(ES_INDEX)"

# =============================================================================
# Advanced Targets
# =============================================================================

# Clean build artifacts
clean:
	@$(MAKE) -C $(BUILD_REPORT_DIR) clean
	@rm -rf $(GENERATED_DIR)/*
	@echo "✓ Report artifacts cleaned from REPORT/generated/"
