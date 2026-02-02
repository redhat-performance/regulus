# REPORT/Makefile
# Central makefile for all report-related operations
# Delegates to build_report/Makefile for dashboard and ElasticSearch operations

.PHONY: help summary summary-with-testbed-info dashboard dashboard-stop dashboard-restart dashboard-status \
        flatten flatten-pretty es-upload es-template es-check es-full \
        es-index-stats es-template-info es-index-mapping \
        es-list-batches es-batch-count es-batch-info es-delete-batch es-show-last-batch \
        clean

# Configuration
PYTHON := python3
BUILD_REPORT_DIR := build_report
DASHBOARD_DIR := dashboard
ES_INTEGRATION_DIR := es_integration
REPORT_DIR := $(shell pwd)
GENERATED_DIR := $(REPORT_DIR)/generated
REG_ROOT ?= $(shell cd .. && pwd)
ES_INDEX ?= regulus-results

# Helper to determine ES_URL with priority: env > /secret > lab.config
# Usage: @$(SOURCE_ES_CONFIG); your_command_using_$$ES_URL
# Note: This exports ES_URL for use in subprocesses
SOURCE_ES_CONFIG = \
	if [ -n "$${ES_URL:-}" ]; then \
		export ES_URL; \
	elif [ -d "/secret" ]; then \
		ES_USER=$$(cat /secret/username 2>/dev/null || echo ""); \
		ES_PASSWORD=$$(cat /secret/password 2>/dev/null || echo ""); \
		ES_HOST=$$(cat /secret/host 2>/dev/null || echo ""); \
		if [ -z "$$ES_HOST" ]; then \
			echo "ERROR: /secret/host is empty or not readable"; \
			exit 1; \
		fi; \
		if [ -n "$$ES_USER" ] && [ -n "$$ES_PASSWORD" ]; then \
			export ES_URL="https://$${ES_USER}:$${ES_PASSWORD}@$${ES_HOST}"; \
		else \
			export ES_URL="https://$${ES_HOST}"; \
		fi; \
	elif [ -f "$(REG_ROOT)/lab.config" ]; then \
		. $(REG_ROOT)/lab.config; \
		if [ -z "$${ES_URL:-}" ]; then \
			echo "ERROR: lab.config must define ES_URL"; \
			exit 1; \
		fi; \
		export ES_URL; \
	else \
		echo "ERROR: No ES configuration found."; \
		echo "  - No ES_URL environment variable"; \
		echo "  - No /secret/ directory (Kubernetes secrets)"; \
		echo "  - No $(REG_ROOT)/lab.config file"; \
		exit 1; \
	fi

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
	@echo "ElasticSearch Debug & Info:"
	@echo "  make es-index-stats       - Show ES index statistics"
	@echo "  make es-template-info     - Show ES index template details"
	@echo "  make es-index-mapping     - Show current index mapping"
	@echo ""
	@echo "Batch Management:"
	@echo "  make es-list-batches                     - List all upload batches"
	@echo "  make es-batch-count ES_BATCH_ID=<uuid>   - Count documents in batch"
	@echo "  make es-batch-info ES_BATCH_ID=<uuid>    - Show batch details"
	@echo "  make es-delete-batch ES_BATCH_ID=<uuid>  - Delete all documents in batch"
	@echo "  make es-show-last-batch                  - Show most recent batch"
	@echo ""
	@echo "Configuration:"
	@echo "  REG_ROOT    = $(REG_ROOT)"
	@echo "  ES_URL      = Set by caller (from lab.config or environment)"
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
	@cd $(REG_ROOT) && REG_ROOT=$(REG_ROOT) bash REPORT/$(BUILD_REPORT_DIR)/build_report --formats html csv --output REPORT/generated/report
	@echo ""
	@echo "Flattening report.json to NDJSON for ElasticSearch..."
	@$(PYTHON) $(ES_INTEGRATION_DIR)/flatten_to_es.py $(GENERATED_DIR)/report.json -o $(GENERATED_DIR)/reports.ndjson --es-index $${ES_INDEX:-regulus-results}
	@echo ""
	@echo "✓ Report generation complete:"
	@echo "  - Unflatten: $(GENERATED_DIR)/report.json"
	@echo "  - Flatten:   $(GENERATED_DIR)/reports.ndjson"
	@ls -lh $(GENERATED_DIR)/report.json $(GENERATED_DIR)/reports.ndjson 2>/dev/null || true

summary-with-testbed-info:
	@mkdir -p $(GENERATED_DIR)
	@# First generate base report.json if it doesn't exist
	@if [ ! -f "$(GENERATED_DIR)/report.json" ]; then \
		echo "Base report.json not found. Generating it first..."; \
		echo ""; \
		cd $(REG_ROOT) && REG_ROOT=$(REG_ROOT) bash REPORT/$(BUILD_REPORT_DIR)/build_report --formats html csv --output REPORT/generated/report; \
		echo ""; \
	fi
	@echo "Generating report with testbed info..."
	@cd $(REG_ROOT) && REG_ROOT=$(REG_ROOT) bash REPORT/assembly/assemble_report.sh
	@echo ""
	@echo "Flattening report-with-testbed-info.json to NDJSON for ElasticSearch..."
	@$(PYTHON) $(ES_INTEGRATION_DIR)/flatten_to_es.py $(GENERATED_DIR)/report-with-testbed-info.json -o $(GENERATED_DIR)/reports-with-testbed-info.ndjson --es-index $${ES_INDEX:-regulus-results}
	@echo ""
	@echo "✓ Report with testbed info generation complete:"
	@echo "  - Unflatten: $(GENERATED_DIR)/report-with-testbed-info.json"
	@echo "  - Flatten:   $(GENERATED_DIR)/reports-with-testbed-info.ndjson"
	@ls -lh $(GENERATED_DIR)/report-with-testbed-info.json $(GENERATED_DIR)/reports-with-testbed-info.ndjson 2>/dev/null || true

# =============================================================================
# Dashboard Targets
# =============================================================================

dashboard:
	@echo "Starting dashboard with reports from: $(GENERATED_DIR)"
	@$(PYTHON) $(DASHBOARD_DIR)/run_dashboard.py --reports $(GENERATED_DIR)

dashboard-stop:
	@echo "Stopping dashboard instances..."
	@ps aux | grep "$(DASHBOARD_DIR)/run_dashboard.py" | grep -v grep | awk '{print $$2}' | xargs kill 2>/dev/null || echo "No dashboard instances running"

dashboard-restart: dashboard-stop
	@sleep 2
	@echo "Restarting dashboard..."
	@$(MAKE) dashboard

dashboard-status:
	@echo "Dashboard Status:"
	@ps aux | grep "$(DASHBOARD_DIR)/run_dashboard.py" | grep -v grep || echo "  No dashboard instances running"

# =============================================================================
# ElasticSearch Targets
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
		$(PYTHON) $(ES_INTEGRATION_DIR)/flatten_to_es.py $(GENERATED_DIR)/report.json -o $(GENERATED_DIR)/reports.ndjson --es-index $(ES_INDEX); \
		echo "✓ Flatten complete: $(GENERATED_DIR)/reports.ndjson"; \
	fi

# Create human-readable pretty JSON
flatten-pretty: flatten
	@if [ ! -f "$(GENERATED_DIR)/reports.ndjson" ]; then \
		echo "Error: $(GENERATED_DIR)/reports.ndjson does not exist"; \
		echo "Run 'make flatten' first to generate the NDJSON file"; \
		exit 1; \
	fi
	@echo "Creating pretty-printed version of flattened data..."
	@grep -v '{"index"' $(GENERATED_DIR)/reports.ndjson | $(PYTHON) -c "import sys, json; docs = [json.loads(line) for line in sys.stdin if line.strip()]; print(json.dumps(docs, indent=2))" > $(GENERATED_DIR)/reports_pretty.json
	@echo "✓ Pretty-printed JSON saved to: $(GENERATED_DIR)/reports_pretty.json"
	@ls -lh $(GENERATED_DIR)/reports_pretty.json

# ElasticSearch operations
es-check:
	@$(SOURCE_ES_CONFIG); \
	echo "Checking ElasticSearch connection at $${ES_URL}..."; \
	curl -s "$${ES_URL}" > /dev/null && \
		echo "✓ ElasticSearch is reachable at $${ES_URL}" || \
		echo "✗ Cannot connect to ElasticSearch at $${ES_URL}"

es-template: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "Detecting platform and applying index template..."; \
	PLATFORM_VARS=$$(export ES_URL="$${ES_URL}"; bash $(ES_INTEGRATION_DIR)/detect_platform.sh 2>&1); \
	if [ $$? -ne 0 ]; then \
		echo "ERROR: Failed to detect platform"; \
		echo "$$PLATFORM_VARS"; \
		exit 1; \
	fi; \
	eval "$$PLATFORM_VARS"; \
	echo "Detected platform: $$PLATFORM (version $$VERSION)"; \
	echo "Applying template: $$TEMPLATE_FILE"; \
	echo ""; \
	curl -X PUT "$${ES_URL}/_index_template/regulus-template" \
		-H 'Content-Type: application/json' \
		-d @$(ES_INTEGRATION_DIR)/$${TEMPLATE_FILE} | $(PYTHON) -m json.tool; \
	echo ""; \
	echo "✓ Index template applied successfully"; \
	echo "  Platform: $$PLATFORM"; \
	echo "  Template: $$TEMPLATE_FILE"

es-upload:
	@if [ ! -f "$(GENERATED_DIR)/reports.ndjson" ]; then \
		echo "reports.ndjson not found. Running 'make summary' to generate it..."; \
		$(MAKE) summary; \
	fi
	@$(SOURCE_ES_CONFIG); \
	echo "Uploading reports to ElasticSearch..."; \
	echo "  Source: $(GENERATED_DIR)/reports.ndjson"; \
	echo "  ES URL: $${ES_URL}"; \
	echo "  ES Index: $(ES_INDEX)"; \
	echo "Uploading $$(grep -c '{"index"' $(GENERATED_DIR)/reports.ndjson 2>/dev/null || echo 0) documents..."; \
	curl -s -H "Content-Type: application/x-ndjson" \
		-XPOST "$${ES_URL}/$(ES_INDEX)/_bulk" \
		--data-binary @$(GENERATED_DIR)/reports.ndjson | \
		$(PYTHON) $(ES_INTEGRATION_DIR)/debug_upload_errors.py

# Complete ElasticSearch workflow
es-full: summary es-template es-upload
	@echo ""
	@echo "✓ Complete ElasticSearch workflow finished:"
	@echo "  - Report generated: $(GENERATED_DIR)/report.json"
	@echo "  - Flattened to: $(GENERATED_DIR)/reports.ndjson"
	@echo "  - Uploaded to ES index: $(ES_INDEX)"

# =============================================================================
# ElasticSearch Debug and Info Targets
# =============================================================================

es-index-stats: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "=========================================="; \
	echo "  ElasticSearch Index Statistics"; \
	echo "=========================================="; \
	echo ""; \
	echo "Index: $(ES_INDEX)"; \
	echo "URL: $${ES_URL}"; \
	echo ""; \
	echo "Detailed Stats (verbose):"; \
	curl -s "$${ES_URL}/_cat/indices/$(ES_INDEX)?v&h=health,status,index,uuid,pri,rep,docs.count,docs.deleted,store.size,pri.store.size"; \
	echo ""; \
	echo ""; \
	echo "Index Settings and Stats (JSON):"; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_stats" | $(PYTHON) -m json.tool 2>/dev/null || echo "Index may not exist yet"

es-template-info: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "=========================================="; \
	echo "  ElasticSearch Index Template Info"; \
	echo "=========================================="; \
	echo ""; \
	echo "Template: regulus-template"; \
	echo "URL: $${ES_URL}"; \
	echo ""; \
	curl -s "$${ES_URL}/_index_template/regulus-template" | $(PYTHON) -m json.tool 2>/dev/null || echo "Template does not exist. Run 'make es-template' to create it."

es-index-mapping: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "=========================================="; \
	echo "  ElasticSearch Index Mapping"; \
	echo "=========================================="; \
	echo ""; \
	echo "Index: $(ES_INDEX)"; \
	echo "URL: $${ES_URL}"; \
	echo ""; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_mapping" | $(PYTHON) -m json.tool 2>/dev/null || echo "Index does not exist yet"

# =============================================================================
# Batch Management Targets
# =============================================================================

es-list-batches: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "=========================================="; \
	echo "  Upload Batches in $(ES_INDEX)"; \
	echo "=========================================="; \
	echo ""; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_search?size=0&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"aggs": {"batches": {"terms": {"field": "batch_id.keyword", "size": 100, "order": {"_key": "desc"}}}}}' | \
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
	@$(SOURCE_ES_CONFIG); \
	curl -s "$${ES_URL}/$(ES_INDEX)/_count?pretty" \
		-H 'Content-Type: application/json' \
		-d '{"query": {"term": {"batch_id.keyword": "$(ES_BATCH_ID)"}}}' | \
		$(PYTHON) -c 'import sys, json; print("Documents in batch: {}".format(json.load(sys.stdin)["count"]))'

es-batch-info: es-check
	@if [ -z "$(ES_BATCH_ID)" ]; then \
		echo "ERROR: ES_BATCH_ID required. Usage: make es-batch-info ES_BATCH_ID=<uuid>"; \
		exit 1; \
	fi
	@$(SOURCE_ES_CONFIG); \
	echo "=========================================="; \
	echo "  Batch Information"; \
	echo "=========================================="; \
	echo ""; \
	echo "Batch ID: $(ES_BATCH_ID)"; \
	echo "Index: $(ES_INDEX)"; \
	echo ""; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_search?size=5&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"query": {"term": {"batch_id.keyword": "$(ES_BATCH_ID)"}}, "aggs": {"benchmarks": {"terms": {"field": "benchmark"}}, "models": {"terms": {"field": "model"}}}}' | \
		$(PYTHON) -m json.tool

es-delete-batch: es-check
	@if [ -z "$(ES_BATCH_ID)" ]; then \
		echo "ERROR: ES_BATCH_ID required. Usage: make es-delete-batch ES_BATCH_ID=<uuid>"; \
		exit 1; \
	fi
	@$(SOURCE_ES_CONFIG); \
	echo "=========================================="; \
	echo "  WARNING: Delete Batch"; \
	echo "=========================================="; \
	echo ""; \
	echo "This will DELETE all documents with batch_id=$(ES_BATCH_ID)"; \
	echo "Index: $(ES_INDEX)"; \
	echo ""; \
	$(MAKE) es-batch-count ES_BATCH_ID=$(ES_BATCH_ID); \
	echo ""; \
	read -p "Are you sure you want to delete this batch? [y/N] " confirm && [ "$$confirm" = "y" ] || (echo "Cancelled."; exit 1); \
	echo ""; \
	echo "Deleting batch..."; \
	curl -s -X POST "$${ES_URL}/$(ES_INDEX)/_delete_by_query?pretty" \
		-H 'Content-Type: application/json' \
		-d '{"query": {"term": {"batch_id.keyword": "$(ES_BATCH_ID)"}}}' | \
		$(PYTHON) -m json.tool; \
	echo ""; \
	echo "✓ Batch deleted"

es-show-last-batch: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "Most recent upload batch:"; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_search?size=0&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"aggs": {"latest": {"terms": {"field": "batch_id.keyword", "size": 1, "order": {"max_timestamp": "desc"}}, "aggs": {"max_timestamp": {"max": {"field": "@timestamp"}}}}}}' | \
		$(PYTHON) -c 'import sys, json; \
		data = json.load(sys.stdin); \
		buckets = data.get("aggregations", {}).get("latest", {}).get("buckets", []); \
		print("Batch ID: {}".format(buckets[0]["key"]) if buckets else "No batches found"); \
		print("Documents: {}".format(buckets[0]["doc_count"]) if buckets else ""); \
		print("Last upload: {}".format(buckets[0]["max_timestamp"]["value_as_string"]) if buckets else "")'

# =============================================================================
# Advanced Targets
# =============================================================================

# Clean build artifacts
clean:
	@echo "Cleaning temporary files..."
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@rm -rf $(GENERATED_DIR)/*
	@echo "✓ Report artifacts cleaned from REPORT/generated/"
