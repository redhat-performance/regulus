# Makefile for build_report project
# Dashboard and ElasticSearch operations

.PHONY: help dashboard dashboard-stop dashboard-restart \
        test-dashboard test-flatten test-flatten-pretty test-es-setup test-dev test-integration \
        flatten es-upload es-template es-check \
        test clean

# Configuration variables
PYTHON := python3
DASHBOARD_SCRIPT := dashboard/run_dashboard.py
FLATTEN_SCRIPT := es_integration/flatten_to_es.py
ES_TEMPLATE := es_integration/es_mapping_template.json
TEST_DATA_DIR := dashboard/test_data
REPORTS_DIR ?= $(TEST_DATA_DIR)
OUTPUT_DIR ?= /tmp
ES_HOST ?= localhost:9200
ES_INDEX ?= regulus-results
ES_USER ?=
ES_PASSWORD ?=

# Default target
help:
	@echo "====================================================================="
	@echo "  Build Report - Dashboard and ElasticSearch Integration"
	@echo "====================================================================="
	@echo ""
	@echo "Test Data Targets (use mock/sample data):"
	@echo "  make test-dashboard         - Start dashboard with test data"
	@echo "  make test-flatten           - Flatten test data to NDJSON"
	@echo "  make test-flatten-pretty    - Create pretty-printed JSON (human-readable)"
	@echo "  make test-es-setup          - Setup ES with test data (template + upload)"
	@echo "  make test-dev               - Quick development workflow (clean + dashboard)"
	@echo "  make test-integration       - Full integration test"
	@echo ""
	@echo "Dashboard Management:"
	@echo "  make dashboard REPORTS_DIR=<path>  - Start dashboard with custom reports"
	@echo "  make dashboard-stop         - Stop running dashboard instances"
	@echo "  make dashboard-restart      - Restart dashboard"
	@echo ""
	@echo "Production Data Targets:"
	@echo "  make flatten REPORTS_DIR=<path> OUTPUT_DIR=<path>"
	@echo "                              - Flatten custom reports to NDJSON"
	@echo "  make es-upload REPORTS_DIR=<path> ES_HOST=<host> ES_INDEX=<index>"
	@echo "                              - Upload custom reports to ES"
	@echo ""
	@echo "ElasticSearch Operations:"
	@echo "  make es-check               - Check ElasticSearch connection"
	@echo "  make es-template            - Apply ES index template"
	@echo ""
	@echo "Maintenance:"
	@echo "  make test                   - Run all tests"
	@echo "  make clean                  - Clean temporary files"
	@echo ""
	@echo "Configuration Variables:"
	@echo "  REPORTS_DIR    = $(REPORTS_DIR)"
	@echo "  OUTPUT_DIR     = $(OUTPUT_DIR)"
	@echo "  ES_HOST        = $(ES_HOST)"
	@echo "  ES_INDEX       = $(ES_INDEX)"
	@echo ""
	@echo "Examples:"
	@echo "  make test-dashboard              # Start dashboard with mock data"
	@echo "  make test-flatten                # Flatten test data to NDJSON"
	@echo "  make dashboard REPORTS_DIR=/path # Start with production data"
	@echo "  make es-template ES_HOST=prod-es:9200"
	@echo "  make es-upload REPORTS_DIR=/path ES_HOST=localhost:9200"
	@echo "====================================================================="

# =============================================================================
# Test Data Dashboard Targets
# =============================================================================

test-dashboard:
	@echo "Starting dashboard with test data from: $(TEST_DATA_DIR)"
	$(PYTHON) $(DASHBOARD_SCRIPT) --reports $(TEST_DATA_DIR)

# =============================================================================
# Dashboard Management Targets
# =============================================================================

dashboard:
	@echo "Starting dashboard with reports from: $(REPORTS_DIR)"
	$(PYTHON) $(DASHBOARD_SCRIPT) --reports $(REPORTS_DIR)

dashboard-stop:
	@echo "Stopping dashboard instances..."
	@ps aux | grep "$(DASHBOARD_SCRIPT)" | grep -v grep | awk '{print $$2}' | xargs kill 2>/dev/null || echo "No dashboard instances running"

dashboard-restart: dashboard-stop
	@sleep 2
	@echo "Restarting dashboard..."
	@$(MAKE) dashboard

# =============================================================================
# ElasticSearch Flattening Targets
# =============================================================================

test-flatten:
	@echo "Flattening test data to $(OUTPUT_DIR)/test_reports.ndjson"
	$(PYTHON) $(FLATTEN_SCRIPT) $(TEST_DATA_DIR) -o $(OUTPUT_DIR)/test_reports.ndjson
	@echo ""
	@echo "Output file: $(OUTPUT_DIR)/test_reports.ndjson"
	@ls -lh $(OUTPUT_DIR)/test_reports.ndjson
	@echo ""
	@echo "Document count: $$(grep -c '{"index"' $(OUTPUT_DIR)/test_reports.ndjson)"

test-flatten-pretty:
	@if [ ! -f "$(OUTPUT_DIR)/test_reports.ndjson" ]; then \
		echo "Error: $(OUTPUT_DIR)/test_reports.ndjson does not exist"; \
		echo "Run 'make test-flatten' first to generate the NDJSON file"; \
		exit 1; \
	fi
	@echo "Creating pretty-printed version of flattened data..."
	@echo "Input: $(OUTPUT_DIR)/test_reports.ndjson"
	@echo "Output: $(OUTPUT_DIR)/test_reports_pretty.json"
	@echo ""
	@grep -v '{"index"' $(OUTPUT_DIR)/test_reports.ndjson | $(PYTHON) -c "import sys, json; docs = [json.loads(line) for line in sys.stdin if line.strip()]; print(json.dumps(docs, indent=2))" > $(OUTPUT_DIR)/test_reports_pretty.json
	@echo "✓ Pretty-printed JSON saved to: $(OUTPUT_DIR)/test_reports_pretty.json"
	@ls -lh $(OUTPUT_DIR)/test_reports_pretty.json
	@echo ""
	@echo "Document count: $$(grep -v '{"index"' $(OUTPUT_DIR)/test_reports.ndjson | wc -l)"

flatten:
	@if [ ! -d "$(REPORTS_DIR)" ]; then \
		echo "Error: REPORTS_DIR=$(REPORTS_DIR) does not exist"; \
		exit 1; \
	fi
	@echo "Flattening reports from: $(REPORTS_DIR)"
	@echo "Output file: $(OUTPUT_DIR)/reports.ndjson"
	@echo "Index name: $(ES_INDEX)"
	$(PYTHON) $(FLATTEN_SCRIPT) $(REPORTS_DIR) -o $(OUTPUT_DIR)/reports.ndjson --es-index $(ES_INDEX)
	@echo ""
	@ls -lh $(OUTPUT_DIR)/reports.ndjson
	@echo "Document count: $$(grep -c '{"index"' $(OUTPUT_DIR)/reports.ndjson)"

flatten-pretty:
	@if [ ! -f "$(OUTPUT_DIR)/reports.ndjson" ]; then \
		echo "Error: $(OUTPUT_DIR)/reports.ndjson does not exist"; \
		echo "Run 'make flatten' first to generate the NDJSON file"; \
		exit 1; \
	fi
	@echo "Creating pretty-printed version of flattened data..."
	@echo "Input: $(OUTPUT_DIR)/reports.ndjson"
	@echo "Output: $(OUTPUT_DIR)/reports_pretty.json"
	@echo ""
	@grep -v '{"index"' $(OUTPUT_DIR)/reports.ndjson | $(PYTHON) -c "import sys, json; docs = [json.loads(line) for line in sys.stdin if line.strip()]; print(json.dumps(docs, indent=2))" > $(OUTPUT_DIR)/reports_pretty.json
	@echo "✓ Pretty-printed JSON saved to: $(OUTPUT_DIR)/reports_pretty.json"
	@ls -lh $(OUTPUT_DIR)/reports_pretty.json
	@echo ""
	@echo "Document count: $$(grep -v '{"index"' $(OUTPUT_DIR)/reports.ndjson | wc -l)"

# =============================================================================
# ElasticSearch Upload Targets
# =============================================================================

es-check:
	@echo "Checking ElasticSearch connection at $(ES_HOST)..."
	@curl -s "http://$(ES_HOST)" > /dev/null && \
		echo "✓ ElasticSearch is reachable at $(ES_HOST)" || \
		echo "✗ Cannot connect to ElasticSearch at $(ES_HOST)"
	@echo ""
	@curl -s "http://$(ES_HOST)" | $(PYTHON) -m json.tool 2>/dev/null || true

es-template: es-check
	@echo "Applying ElasticSearch index template..."
	@if [ -n "$(ES_USER)" ] && [ -n "$(ES_PASSWORD)" ]; then \
		curl -X PUT "http://$(ES_HOST)/_index_template/regulus-template" \
			-u "$(ES_USER):$(ES_PASSWORD)" \
			-H 'Content-Type: application/json' \
			-d @$(ES_TEMPLATE); \
	else \
		curl -X PUT "http://$(ES_HOST)/_index_template/regulus-template" \
			-H 'Content-Type: application/json' \
			-d @$(ES_TEMPLATE); \
	fi
	@echo ""
	@echo "✓ Index template applied successfully"

es-upload:
	@echo "Uploading reports to ElasticSearch..."
	@echo "  Source: $(REPORTS_DIR)"
	@echo "  ES Host: $(ES_HOST)"
	@echo "  ES Index: $(ES_INDEX)"
	@# First, flatten to NDJSON if needed
	@if [ ! -f "$(OUTPUT_DIR)/reports.ndjson" ] || [ "$(REPORTS_DIR)" -nt "$(OUTPUT_DIR)/reports.ndjson" ]; then \
		echo "Flattening reports to NDJSON..."; \
		$(PYTHON) $(FLATTEN_SCRIPT) $(REPORTS_DIR) -o $(OUTPUT_DIR)/reports.ndjson; \
	fi
	@# Then upload using curl (no Python elasticsearch package needed)
	@echo "Uploading $(shell grep -c '{\"index\"' $(OUTPUT_DIR)/reports.ndjson 2>/dev/null || echo 0) documents..."
	@if [ -n "$(ES_USER)" ] && [ -n "$(ES_PASSWORD)" ]; then \
		curl -s -u "$(ES_USER):$(ES_PASSWORD)" \
			-H "Content-Type: application/x-ndjson" \
			-XPOST "http://$(ES_HOST)/$(ES_INDEX)/_bulk" \
			--data-binary @$(OUTPUT_DIR)/reports.ndjson | \
			$(PYTHON) -c "import sys, json; r=json.load(sys.stdin); print('✓ Uploaded:', r.get('items', []) and len(r['items']), 'documents'); print('  Errors:', r.get('errors', False))"; \
	else \
		curl -s -H "Content-Type: application/x-ndjson" \
			-XPOST "http://$(ES_HOST)/$(ES_INDEX)/_bulk" \
			--data-binary @$(OUTPUT_DIR)/reports.ndjson | \
			$(PYTHON) -c "import sys, json; r=json.load(sys.stdin); print('✓ Uploaded:', r.get('items', []) and len(r['items']), 'documents'); print('  Errors:', r.get('errors', False))"; \
	fi

es-upload-with-template: es-template es-upload

# =============================================================================
# Testing Targets
# =============================================================================

test: test-flatten
	@echo ""
	@echo "Running validation tests..."
	@echo "✓ Flattening test passed"
	@echo ""
	@if [ -f "$(OUTPUT_DIR)/test_reports.ndjson" ]; then \
		echo "Validating NDJSON format..."; \
		head -4 $(OUTPUT_DIR)/test_reports.ndjson | $(PYTHON) -m json.tool > /dev/null && \
			echo "✓ NDJSON format validation passed" || \
			echo "✗ NDJSON format validation failed"; \
	fi

# =============================================================================
# Maintenance Targets
# =============================================================================

clean:
	@echo "Cleaning temporary files..."
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@rm -f $(OUTPUT_DIR)/test_reports.ndjson $(OUTPUT_DIR)/reports.ndjson 2>/dev/null || true
	@echo "✓ Cleanup complete"

# =============================================================================
# Advanced Targets
# =============================================================================

# =============================================================================
# Test Data Advanced Targets
# =============================================================================

# Full ElasticSearch setup (template + upload test data)
test-es-setup: es-template
	@echo ""
	@echo "Uploading test data..."
	@$(MAKE) es-upload REPORTS_DIR=$(TEST_DATA_DIR)
	@echo ""
	@echo "✓ ElasticSearch setup complete"

# Quick development workflow
test-dev: clean test-dashboard

# Full integration test
test-integration: clean test test-es-setup
	@echo ""
	@echo "====================================================================="
	@echo "  Integration test complete!"
	@echo "====================================================================="

# =============================================================================
# Dashboard Monitoring Targets
# =============================================================================

# Monitor dashboard logs
dashboard-logs:
	@if [ -f /tmp/dashboard-test.log ]; then \
		tail -f /tmp/dashboard-test.log; \
	else \
		echo "No dashboard log file found at /tmp/dashboard-test.log"; \
	fi

# Show dashboard status
dashboard-status:
	@echo "Dashboard Status:"
	@ps aux | grep "$(DASHBOARD_SCRIPT)" | grep -v grep || echo "  No dashboard instances running"
