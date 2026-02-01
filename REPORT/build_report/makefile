# Makefile for build_report project
# Dashboard and ElasticSearch operations

.PHONY: help dashboard dashboard-stop dashboard-restart \
        test-dashboard test-flatten test-flatten-pretty test-es-setup test-dev test-integration \
        flatten es-upload es-template es-check es-index-stats es-template-info es-index-mapping \
        es-ilm-policy es-ilm-info es-ilm-explain es-bootstrap-index \
        es-list-batches es-batch-count es-batch-info es-delete-batch es-show-last-batch \
        test clean

# Configuration variables
PYTHON := python3
DASHBOARD_SCRIPT := dashboard/run_dashboard.py
FLATTEN_SCRIPT := es_integration/flatten_to_es.py
ES_TEMPLATE := es_integration/es_mapping_template.json
ES_ILM_POLICY := es_integration/es_ilm_policy.json
TEST_DATA_DIR := dashboard/test_data
REPORTS_DIR ?= ../generated
OUTPUT_DIR ?= /tmp

# Determine REG_ROOT (regulus root directory)
# Try multiple methods to find it: env var, parent directories
REG_ROOT ?= $(shell \
	if [ -n "$$REG_ROOT" ]; then \
		echo "$$REG_ROOT"; \
	elif [ -f "../../lab.config" ]; then \
		cd ../.. && pwd; \
	elif [ -f "../../../lab.config" ]; then \
		cd ../../.. && pwd; \
	else \
		cd ../.. && pwd; \
	fi)

# ElasticSearch configuration
# ES_URL must be set by the caller (outside REPORT/) with complete connection info
# Examples:
#   Dev:  ES_URL="http://localhost:9200"
#   Prod: ES_URL="https://user:pass@search-perfscale-pro-xxxxx.us-west-2.es.amazonaws.com"
# ES_INDEX - Index name for upload operations
ES_INDEX ?= regulus-results

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
	@echo "  make es-upload REPORTS_DIR=<path> ES_URL=<url> ES_INDEX=<index>"
	@echo "                              - Upload custom reports to ES"
	@echo ""
	@echo "ElasticSearch Operations:"
	@echo "  make es-check               - Check ElasticSearch connection"
	@echo "  make es-template            - Apply ES index template"
	@echo "  make es-index-stats         - Show ES index statistics"
	@echo "  make es-template-info       - Show ES index template details"
	@echo "  make es-index-mapping       - Show current index mapping"
	@echo ""
	@echo "Index Lifecycle Management (ILM):"
	@echo "  make es-ilm-policy          - Apply ILM policy for data retention"
	@echo "  make es-ilm-info            - Show current ILM policy details"
	@echo "  make es-ilm-explain         - Explain ILM phase for an index"
	@echo "  make es-bootstrap-index     - Create initial bootstrapped index"
	@echo ""
	@echo "Batch Management:"
	@echo "  make es-list-batches                     - List all upload batches"
	@echo "  make es-batch-count ES_BATCH_ID=<uuid>   - Count documents in batch"
	@echo "  make es-batch-info ES_BATCH_ID=<uuid>    - Show batch details"
	@echo "  make es-delete-batch ES_BATCH_ID=<uuid>  - Delete all documents in batch"
	@echo "  make es-show-last-batch                  - Show most recent batch"
	@echo ""
	@echo "Maintenance:"
	@echo "  make test                   - Run all tests"
	@echo "  make clean                  - Clean temporary files"
	@echo ""
	@echo "Configuration Variables:"
	@echo "  REPORTS_DIR    = $(REPORTS_DIR)"
	@echo "  OUTPUT_DIR     = $(OUTPUT_DIR)"
	@echo "  ES_URL         = Complete ES connection URL (set by caller)"
	@echo "  ES_INDEX       = $(ES_INDEX)"
	@echo ""
	@echo "Examples:"
	@echo "  make test-dashboard              # Start dashboard with mock data"
	@echo "  make test-flatten                # Flatten test data to NDJSON"
	@echo "  make dashboard REPORTS_DIR=/path # Start with production data"
	@echo "  make es-template ES_URL=http://localhost:9200"
	@echo "  make es-upload REPORTS_DIR=/path ES_URL=https://user:pass@prod-es:9200"
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
	@if [ -z "$(ES_URL)" ]; then \
		echo "ERROR: ES_URL must be set (determined outside REPORT/)"; \
		exit 1; \
	fi; \
	echo "Checking ElasticSearch connection at $(ES_URL)..."; \
	curl -s "$(ES_URL)" > /dev/null && \
		echo "✓ ElasticSearch is reachable at $(ES_URL)" || \
		echo "✗ Cannot connect to ElasticSearch at $(ES_URL)"

es-template: es-check
	@echo "Detecting platform and applying index template..."
	@eval $$(es_integration/detect_platform.sh); \
	echo "Detected platform: $$PLATFORM (version $$VERSION)"; \
	echo "Applying template: $$TEMPLATE_FILE"; \
	echo ""; \
	curl -X PUT "$(ES_URL)/_index_template/regulus-template" \
		-H 'Content-Type: application/json' \
		-d @es_integration/$${TEMPLATE_FILE} | $(PYTHON) -m json.tool; \
	echo ""; \
	echo "✓ Index template applied successfully"; \
	echo "  Platform: $$PLATFORM"; \
	echo "  Template: $$TEMPLATE_FILE"

es-upload:
	@echo "Uploading reports to ElasticSearch..."
	@echo "  Source: $(REPORTS_DIR)"
	@echo "  ES URL: $(ES_URL)"
	@echo "  ES Index: $(ES_INDEX)"
	@# Check if reports.ndjson already exists in REPORTS_DIR
	@if [ -f "$(REPORTS_DIR)/reports.ndjson" ]; then \
		echo "Using existing NDJSON file: $(REPORTS_DIR)/reports.ndjson"; \
		NDJSON_FILE="$(REPORTS_DIR)/reports.ndjson"; \
	else \
		echo "No pre-generated NDJSON found, flattening reports..."; \
		$(PYTHON) $(FLATTEN_SCRIPT) $(REPORTS_DIR) -o $(OUTPUT_DIR)/reports.ndjson; \
		NDJSON_FILE="$(OUTPUT_DIR)/reports.ndjson"; \
	fi; \
	echo "Uploading $$(grep -c '{\"index\"' $$NDJSON_FILE 2>/dev/null || echo 0) documents..."; \
	curl -s -H "Content-Type: application/x-ndjson" \
		-XPOST "$(ES_URL)/$(ES_INDEX)/_bulk" \
		--data-binary @$$NDJSON_FILE | \
		$(PYTHON) es_integration/debug_upload_errors.py

es-upload-with-template: es-template es-upload

# =============================================================================
# ElasticSearch Debug Targets
# =============================================================================

es-index-stats: es-check
	@echo "=========================================="
	@echo "  ElasticSearch Index Statistics"
	@echo "=========================================="
	@echo ""
	@echo "Index: $(ES_INDEX)"
	@echo "URL: $(ES_URL)"
	@echo ""
	@echo "Detailed Stats (verbose):"
	@curl -s "$(ES_URL)/_cat/indices/$(ES_INDEX)?v&h=health,status,index,uuid,pri,rep,docs.count,docs.deleted,store.size,pri.store.size"
	@echo ""
	@echo ""
	@echo "Index Settings and Stats (JSON):"
	@curl -s "$(ES_URL)/$(ES_INDEX)/_stats" | $(PYTHON) -m json.tool 2>/dev/null || echo "Index may not exist yet"

es-template-info: es-check
	@echo "=========================================="
	@echo "  ElasticSearch Index Template Info"
	@echo "=========================================="
	@echo ""
	@echo "Template: regulus-template"
	@echo "URL: $(ES_URL)"
	@echo ""
	@curl -s "$(ES_URL)/_index_template/regulus-template" | $(PYTHON) -m json.tool 2>/dev/null || echo "Template does not exist. Run 'make es-template' to create it."

es-index-mapping: es-check
	@echo "=========================================="
	@echo "  ElasticSearch Index Mapping"
	@echo "=========================================="
	@echo ""
	@echo "Index: $(ES_INDEX)"
	@echo "URL: $(ES_URL)"
	@echo ""
	@curl -s "$(ES_URL)/$(ES_INDEX)/_mapping" | $(PYTHON) -m json.tool 2>/dev/null || echo "Index does not exist yet"

# =============================================================================
# Index Lifecycle Management (ILM/ISM) Targets
# Auto-detects ElasticSearch vs OpenSearch and uses appropriate APIs
# =============================================================================

es-ilm-policy: es-check
	@echo "Detecting platform and applying lifecycle policy..."
	@eval $$(es_integration/detect_platform.sh); \
	echo "Detected platform: $$PLATFORM (version $$VERSION)"; \
	echo "Applying policy: $$POLICY_NAME"; \
	echo ""; \
	curl -X PUT "$(ES_URL)$${POLICY_ENDPOINT}/$${POLICY_NAME}" \
		-H 'Content-Type: application/json' \
		-d @es_integration/$${POLICY_FILE} | $(PYTHON) -m json.tool; \
	echo ""; \
	echo "✓ Lifecycle policy applied successfully"; \
	echo "  Platform: $$PLATFORM"; \
	echo "  Policy: $$POLICY_NAME"; \
	echo "  Phases: hot (30d) -> warm (7d) -> cold (30d) -> delete (90d)"

es-ilm-info: es-check
	@echo "=========================================="
	@echo "  Lifecycle Policy Information"
	@echo "=========================================="
	@echo ""
	@eval $$(es_integration/detect_platform.sh); \
	echo "Platform: $$PLATFORM (version $$VERSION)"; \
	echo "Policy: $$POLICY_NAME"; \
	echo "URL: $(ES_URL)"; \
	echo ""; \
	curl -s "$(ES_URL)$${POLICY_ENDPOINT}/$${POLICY_NAME}" | $(PYTHON) -m json.tool 2>/dev/null || echo "Policy does not exist. Run 'make es-ilm-policy' to create it."

es-ilm-explain: es-check
	@echo "=========================================="
	@echo "  Lifecycle Phase Explanation for Index"
	@echo "=========================================="
	@echo ""
	@eval $$(es_integration/detect_platform.sh); \
	echo "Platform: $$PLATFORM"; \
	echo "Index: $(ES_INDEX)"; \
	echo "URL: $(ES_URL)"; \
	echo ""; \
	curl -s "$(ES_URL)$${POLICY_EXPLAIN_PREFIX}$(ES_INDEX)$${POLICY_EXPLAIN_SUFFIX}" | $(PYTHON) -m json.tool 2>/dev/null || echo "Index does not exist or lifecycle management not enabled yet"

es-bootstrap-index: es-check es-ilm-policy es-template
	@echo "=========================================="
	@echo "  Bootstrapping Rollover Index"
	@echo "=========================================="
	@echo ""
	@eval $$(es_integration/detect_platform.sh); \
	echo "Platform: $$PLATFORM"; \
	echo "Creating initial write index: $(ES_INDEX)-000001"; \
	echo "Write alias: $(ES_INDEX)"; \
	echo ""; \
	echo "{\"aliases\":{\"$(ES_INDEX)\":{\"is_write_index\":true}}}" > /tmp/bootstrap-index.json; \
	curl -X PUT "$(ES_URL)/$(ES_INDEX)-000001" \
		-H 'Content-Type: application/json' \
		-d @/tmp/bootstrap-index.json | $(PYTHON) -m json.tool; \
	rm -f /tmp/bootstrap-index.json; \
	echo ""; \
	echo "✓ Rollover-enabled index created successfully"; \
	echo "  Platform: $$PLATFORM"; \
	echo "  Index: $(ES_INDEX)-000001"; \
	echo "  Alias: $(ES_INDEX) (write)"; \
	echo ""; \
	echo "Next steps:"; \
	echo "  1. Upload data using: make es-upload"; \
	echo "  2. Monitor rollover: make es-ilm-explain"; \
	echo "  3. Check index stats: make es-index-stats"

# =============================================================================
# Batch Management Targets
# =============================================================================

es-list-batches: es-check
	@echo "=========================================="
	@echo "  Upload Batches in $(ES_INDEX)"
	@echo "=========================================="
	@echo ""
	@curl -s "$(ES_URL)/$(ES_INDEX)/_search?size=0&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"aggs": {"batches": {"terms": {"field": "batch_id.keyword", "size": 100}}}}' | \
		$(PYTHON) -c 'import sys, json; \
		data = json.load(sys.stdin); \
		buckets = data.get("aggregations", {}).get("batches", {}).get("buckets", []); \
		print("Found {} unique batch(es):\n".format(len(buckets))); \
		[print("  {} ({} documents)".format(b["key"], b["doc_count"])) for b in buckets]'

es-batch-count: es-check
	@if [ -z "$(ES_BATCH_ID)" ]; then \
		echo "ERROR: ES_BATCH_ID required. Usage: make es-batch-count ES_BATCH_ID=<uuid>"; \
		exit 1; \
	fi
	@curl -s "$(ES_URL)/$(ES_INDEX)/_count?pretty" \
		-H 'Content-Type: application/json' \
		-d '{"query": {"term": {"batch_id.keyword": "$(ES_BATCH_ID)"}}}' | \
		$(PYTHON) -c 'import sys, json; print("Documents in batch: {}".format(json.load(sys.stdin)["count"]))'

es-batch-info: es-check
	@if [ -z "$(ES_BATCH_ID)" ]; then \
		echo "ERROR: ES_BATCH_ID required. Usage: make es-batch-info ES_BATCH_ID=<uuid>"; \
		exit 1; \
	fi
	@echo "=========================================="
	@echo "  Batch Information"
	@echo "=========================================="
	@echo ""
	@echo "Batch ID: $(ES_BATCH_ID)"
	@echo "Index: $(ES_INDEX)"
	@echo ""
	@curl -s "$(ES_URL)/$(ES_INDEX)/_search?size=5&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"query": {"term": {"batch_id.keyword": "$(ES_BATCH_ID)"}}, "aggs": {"benchmarks": {"terms": {"field": "benchmark"}}, "models": {"terms": {"field": "model"}}}}' | \
		$(PYTHON) -m json.tool

es-delete-batch: es-check
	@if [ -z "$(ES_BATCH_ID)" ]; then \
		echo "ERROR: ES_BATCH_ID required. Usage: make es-delete-batch ES_BATCH_ID=<uuid>"; \
		exit 1; \
	fi
	@echo "=========================================="
	@echo "  WARNING: Delete Batch"
	@echo "=========================================="
	@echo ""
	@echo "This will DELETE all documents with batch_id=$(ES_BATCH_ID)"
	@echo "Index: $(ES_INDEX)"
	@echo ""
	@$(MAKE) es-batch-count ES_BATCH_ID=$(ES_BATCH_ID)
	@echo ""
	@read -p "Are you sure you want to delete this batch? [y/N] " confirm && [ "$$confirm" = "y" ] || (echo "Cancelled."; exit 1)
	@echo ""
	@echo "Deleting batch..."
	@curl -s -X POST "$(ES_URL)/$(ES_INDEX)/_delete_by_query?pretty" \
		-H 'Content-Type: application/json' \
		-d '{"query": {"term": {"batch_id.keyword": "$(ES_BATCH_ID)"}}}' | \
		$(PYTHON) -m json.tool
	@echo ""
	@echo "✓ Batch deleted"

es-show-last-batch: es-check
	@echo "Most recent upload batch:"
	@curl -s "$(ES_URL)/$(ES_INDEX)/_search?size=0&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"aggs": {"latest": {"terms": {"field": "batch_id.keyword", "size": 1, "order": {"max_timestamp": "desc"}}, "aggs": {"max_timestamp": {"max": {"field": "@timestamp"}}}}}}' | \
		$(PYTHON) -c 'import sys, json; \
		data = json.load(sys.stdin); \
		buckets = data.get("aggregations", {}).get("latest", {}).get("buckets", []); \
		print("Batch ID: {}".format(buckets[0]["key"]) if buckets else "No batches found"); \
		print("Documents: {}".format(buckets[0]["doc_count"]) if buckets else ""); \
		print("Last upload: {}".format(buckets[0]["max_timestamp"]["value_as_string"]) if buckets else "")'

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
